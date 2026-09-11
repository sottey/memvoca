# Phase 1 architecture

```text
Omi DevKit 2 -- BLE --> Memvoca on iPhone -- WebSocket --> Strongbox receiver
```

The iPhone is a gateway: it handles Bluetooth, a small in-memory forwarding
buffer, and reconnect attempts. Strongbox receives raw packets and owns all
future expensive work. The iPhone does not transcribe, diarize, embed, search,
or persist transcripts.

## Phase 1 transport

The configurable endpoint is a WebSocket URL ending in `/stream`; for example,
`ws://192.168.7.215:8766/stream`. The app sends one UTF-8 JSON metadata message
immediately before each binary WebSocket message. The binary message is the
unchanged BLE notification payload.

Required metadata fields are `type` (`packet`), `device_id`, `session_id`,
`sequence`, and ISO-8601 `timestamp`. Optional fields describe the source
codec, sample rate, channel count, and payload layout.

The receiver has two endpoints:

* `GET /health` returns a JSON health and counter snapshot over HTTP.
* `GET /stream` upgrades to WebSocket and accepts metadata/binary pairs.

It binds to `127.0.0.1:8766` by default. Use `--host 0.0.0.0` only for an
intentional LAN test. There is deliberately no durable queue, authentication,
or TLS infrastructure in this first local-development proof.

The iPhone buffer is bounded and in-memory. When it fills, it drops the oldest
unforwarded packet and exposes the count in the UI. This is diagnostic
resilience, not a durable audio-recovery design.
