# Dedicated Server Bundle

This folder contains files used to run a dedicated relay/signaling server for the game's WebRTC P2P mode.

## Contents

- `server.py`: Python dedicated relay server that auto-assigns host room codes, logs player joins, and stores uploaded player icons per room.
- `requirements.txt`: Python dependencies for the dedicated relay server.

## Run

```bash
cd dedicated_server
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python server.py
```

Default signaling URL for clients is:

`ws://127.0.0.1:9080`
