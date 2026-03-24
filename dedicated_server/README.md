# Dedicated Server Bundle

This folder contains files used to run a dedicated relay/signaling server for the game's WebRTC P2P mode.

## Contents

- `relay_server.js`: Minimal WebSocket signaling relay for room-based offer/answer/ICE exchange.
- `package.json`: Node.js dependency manifest.
- `.env.example`: Environment variables for port and host binding.

## Run

```bash
cd dedicated_server
npm install
npm start
```

Default signaling URL for clients is:

`ws://127.0.0.1:9080`
