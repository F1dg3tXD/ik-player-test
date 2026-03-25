#!/usr/bin/env python3
import asyncio
import base64
import json
import os
import pathlib
import random
from dataclasses import dataclass, field
from typing import Any

import websockets
from websockets.server import WebSocketServerProtocol

HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", "9080"))
ICON_DIR = pathlib.Path(os.getenv("ICON_DIR", "icons"))
ROOM_CODE_LENGTH = 6
ROOM_CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"


@dataclass
class RoomState:
    peers: dict[int, WebSocketServerProtocol] = field(default_factory=dict)
    profiles: dict[int, dict[str, Any]] = field(default_factory=dict)


rooms: dict[str, RoomState] = {}
socket_to_peer: dict[WebSocketServerProtocol, tuple[str, int]] = {}


def sanitize_room_code(raw_value: Any) -> str:
    return "".join(ch for ch in str(raw_value or "").strip().upper() if ch.isalnum())


def generate_room_code() -> str:
    return "".join(random.choice(ROOM_CODE_CHARS) for _ in range(ROOM_CODE_LENGTH))


def allocate_host_room_code(preferred_room: str) -> str:
    if preferred_room and preferred_room not in rooms:
        return preferred_room
    code = generate_room_code()
    while code in rooms:
        code = generate_room_code()
    return code


async def send_json(ws: WebSocketServerProtocol, payload: dict[str, Any]) -> None:
    if ws.closed:
        return
    await ws.send(json.dumps(payload))


def room_state(room_code: str) -> RoomState:
    if room_code not in rooms:
        rooms[room_code] = RoomState()
    return rooms[room_code]


def save_icon_file(room_code: str, peer_id: int, icon_png_base64: str) -> str:
    room_dir = ICON_DIR / room_code
    room_dir.mkdir(parents=True, exist_ok=True)
    icon_path = room_dir / f"{peer_id}.png"
    if icon_png_base64:
        try:
            icon_bytes = base64.b64decode(icon_png_base64)
            icon_path.write_bytes(icon_bytes)
            return str(icon_path)
        except Exception:
            pass
    return ""


async def broadcast_profile(room_code: str, peer_id: int) -> None:
    state = room_state(room_code)
    profile = state.profiles.get(peer_id)
    if profile is None:
        return
    for target_id, target_ws in state.peers.items():
        if target_id == peer_id:
            continue
        await send_json(
            target_ws,
            {
                "action": "player_profile",
                "peer_id": peer_id,
                "player_name": profile.get("player_name", "Player"),
                "icon_png_base64": profile.get("icon_png_base64", ""),
            },
        )


async def handle_join(ws: WebSocketServerProtocol, data: dict[str, Any]) -> None:
    is_host = bool(data.get("host"))
    preferred_room = sanitize_room_code(data.get("room", ""))
    room_code = allocate_host_room_code(preferred_room) if is_host else (preferred_room or "DEFAULT")
    peer_id = int(data.get("peer_id", 0))
    if peer_id <= 0:
        return

    player_name = str(data.get("player_name", "Player")).strip() or "Player"
    icon_png_base64 = str(data.get("icon_png_base64", ""))

    state = room_state(room_code)
    state.peers[peer_id] = ws
    socket_to_peer[ws] = (room_code, peer_id)

    icon_path = save_icon_file(room_code, peer_id, icon_png_base64)
    state.profiles[peer_id] = {
        "peer_id": peer_id,
        "player_name": player_name,
        "icon_png_base64": icon_png_base64,
        "icon_path": icon_path,
    }

    await send_json(ws, {"action": "room_assigned", "room": room_code})
    await send_json(
        ws,
        {
            "action": "profiles_snapshot",
            "profiles": list(state.profiles.values()),
        },
    )

    for existing_id, existing_ws in state.peers.items():
        if existing_id == peer_id:
            continue
        await send_json(ws, {"action": "peer_joined", "peer_id": existing_id})
        await send_json(existing_ws, {"action": "peer_joined", "peer_id": peer_id})

    await broadcast_profile(room_code, peer_id)
    log_host = "HOST" if is_host else "CLIENT"
    print(f"[ROOM {room_code}] {log_host} joined: {player_name} (peer_id={peer_id})")
    if is_host:
        print(f"[ROOM {room_code}] Assigned host room code: {room_code}")


async def forward_signaling(ws: WebSocketServerProtocol, data: dict[str, Any]) -> None:
    peer_info = socket_to_peer.get(ws)
    if peer_info is None:
        return
    room_code, sender_peer_id = peer_info
    state = room_state(room_code)
    target_id = int(data.get("to", 0))
    target_ws = state.peers.get(target_id)
    if target_ws is None:
        return
    await send_json(
        target_ws,
        {
            "action": data.get("action", ""),
            "from": int(data.get("from", sender_peer_id)),
            "sdp": data.get("sdp"),
            "mid": data.get("mid"),
            "index": data.get("index"),
            "candidate": data.get("candidate"),
        },
    )


async def handle_disconnect(ws: WebSocketServerProtocol) -> None:
    peer_info = socket_to_peer.pop(ws, None)
    if peer_info is None:
        return
    room_code, peer_id = peer_info
    state = room_state(room_code)
    profile = state.profiles.get(peer_id, {})
    player_name = str(profile.get("player_name", "Unknown"))
    state.peers.pop(peer_id, None)
    state.profiles.pop(peer_id, None)
    for other_ws in state.peers.values():
        await send_json(other_ws, {"action": "peer_left", "peer_id": peer_id})
    print(f"[ROOM {room_code}] Disconnected: {player_name} (peer_id={peer_id})")
    if not state.peers:
        rooms.pop(room_code, None)
        print(f"[ROOM {room_code}] Closed (empty room).")


async def handler(ws: WebSocketServerProtocol) -> None:
    await send_json(ws, {"action": "hello"})
    try:
        async for raw_message in ws:
            try:
                data = json.loads(raw_message)
            except json.JSONDecodeError:
                continue
            action = str(data.get("action", ""))
            if action == "join":
                await handle_join(ws, data)
            elif action in {"offer", "answer", "ice"}:
                await forward_signaling(ws, data)
    except websockets.ConnectionClosed:
        pass
    finally:
        await handle_disconnect(ws)


async def main() -> None:
    ICON_DIR.mkdir(parents=True, exist_ok=True)
    print(f"Dedicated relay server running at ws://{HOST}:{PORT}")
    print(f"Player icons saved to: {ICON_DIR.resolve()}")
    async with websockets.serve(handler, HOST, PORT, max_size=4_000_000):
        await asyncio.Future()


if __name__ == "__main__":
    asyncio.run(main())
