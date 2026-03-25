import { WebSocketServer } from 'ws';

const host = process.env.HOST || '0.0.0.0';
const port = Number(process.env.PORT || 9080);

const rooms = new Map();
const ROOM_CODE_LENGTH = 6;
const ROOM_CODE_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

function roomPeers(room) {
  if (!rooms.has(room)) rooms.set(room, new Map());
  return rooms.get(room);
}

function send(ws, payload) {
  if (ws.readyState === ws.OPEN) ws.send(JSON.stringify(payload));
}

function generateRoomCode() {
  let code = '';
  for (let i = 0; i < ROOM_CODE_LENGTH; i += 1) {
    code += ROOM_CODE_CHARS[Math.floor(Math.random() * ROOM_CODE_CHARS.length)];
  }
  return code;
}

function sanitizeRoomCode(rawValue) {
  return String(rawValue || '').trim().toUpperCase().replace(/[^A-Z0-9]/g, '');
}

function getHostRoomCode(preferredRoom) {
  if (preferredRoom && !rooms.has(preferredRoom)) return preferredRoom;
  let generated = generateRoomCode();
  while (rooms.has(generated)) {
    generated = generateRoomCode();
  }
  return generated;
}

const wss = new WebSocketServer({ host, port });

wss.on('connection', (ws) => {
  ws.peerId = null;
  ws.room = null;
  send(ws, { action: 'hello' });

  ws.on('message', (message) => {
    let data;
    try { data = JSON.parse(message.toString()); } catch { return; }

    if (data.action === 'join') {
      const isHost = Boolean(data.host);
      const preferredRoom = sanitizeRoomCode(data.room);
      const room = isHost ? getHostRoomCode(preferredRoom) : (preferredRoom || 'DEFAULT');
      const peerId = Number(data.peer_id || 0);
      if (!peerId) return;
      ws.peerId = peerId;
      ws.room = room;
      const peers = roomPeers(room);
      send(ws, { action: 'room_assigned', room });

      for (const [id, existing] of peers.entries()) {
        if (id !== peerId) {
          send(ws, { action: 'peer_joined', peer_id: id });
          send(existing, { action: 'peer_joined', peer_id: peerId });
        }
      }

      peers.set(peerId, ws);
      return;
    }

    const room = ws.room;
    if (!room) return;

    if (['offer', 'answer', 'ice'].includes(data.action)) {
      const peers = roomPeers(room);
      const target = peers.get(Number(data.to || 0));
      if (!target) return;
      send(target, {
        action: data.action,
        from: Number(data.from || ws.peerId || 0),
        sdp: data.sdp,
        mid: data.mid,
        index: data.index,
        candidate: data.candidate,
      });
    }
  });

  ws.on('close', () => {
    if (!ws.room || !ws.peerId) return;
    const peers = roomPeers(ws.room);
    peers.delete(ws.peerId);
    if (peers.size === 0) rooms.delete(ws.room);
  });
});

console.log(`Relay server listening on ws://${host}:${port}`);
