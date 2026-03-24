# ik-player-test
A procedural co-op prototype in Godot 4.6.

## Networking direction

Steam networking has been removed from the runtime flow.

The project now uses a lightweight WebRTC mesh approach with a WebSocket signaling relay:

- In-game lobby/menu supports hosting and joining a P2P room.
- Players can configure profile name + icon path in the options profile tab.
- Player profile is synchronized to the in-world head display.

## Dedicated server relay

A standalone relay/signaling server bundle is provided in `dedicated_server/` for dedicated-server style deployment.

See `dedicated_server/README.md` for setup and run instructions.

## Credits
"Weeping Angel All poses" (https://skfb.ly/pnPxB) by NO DONT EAT ME CASEOH (Ferris wheel) is licensed under Creative Commons Attribution (http://creativecommons.org/licenses/by/4.0/).
"Lowpoly Van" (https://skfb.ly/pGoPE) by AspectStudios is licensed under Creative Commons Attribution (http://creativecommons.org/licenses/by/4.0/).
