# Memvoca

Memvoca is a privacy-first, self-hosted ambient-audio memory platform. Its
first capture path is an Omi DevKit 2 connected to an iPhone over Bluetooth LE.
The iPhone is a lightweight gateway that sends raw packets to a self-hosted
Strongbox receiver; Strongbox will eventually perform all transcription,
storage, search, and local AI work.

```text
Omi DevKit 2 -- Bluetooth LE --> iPhone -- Wi-Fi/WebSocket --> Strongbox
```

The Mac is a development machine only. The production path has no Mac, Omi
cloud account, hosted transcription service, or hosted AI dependency.

## Current status

The Phase 1 implementation is ready for a physical-device development test:

* The iOS app discovers BLE peripherals, prioritizes names containing `Omi`,
  connects, and reports its GATT database without writing to any characteristic.
* It recognizes the DevKit 2 audio service and enables notifications only when
  the verified service and characteristic UUIDs are present.
* It forwards the unchanged notification payload to a configurable Strongbox
  WebSocket receiver, with a small bounded in-memory retry buffer.
* The Python receiver reports health, connections, packets, and bytes. It does
  not transcribe, retain recordings, use a database, or call external services.

See [the protocol status](docs/omi-devkit2.md) for the evidence boundary and
[the architecture](docs/architecture.md) for the Phase 1 transport contract.

## Development requirements

* macOS with Xcode and an Apple development team configured.
* A physical iPhone running iOS 17 or later. CoreBluetooth scanning does not
  work in the iOS Simulator.
* Python 3.11 or later on Strongbox for the test receiver.
* An Omi DevKit 2. Do not flash it, write undocumented BLE characteristics, or
  modify its SD card for this milestone.

## Run the Strongbox receiver

On Strongbox, from a checkout of this repository:

```sh
cd server
python3 -m venv .venv
. .venv/bin/activate
pip install .
memvoca-receiver
```

The default binds only to `127.0.0.1:8766`. For an intentional LAN test, bind
to Strongbox's LAN interface:

```sh
memvoca-receiver --host 0.0.0.0 --port 8766
```

The health endpoint is `http://HOST:8766/health`; the iPhone stream endpoint is
`ws://HOST:8766/stream`. The Debug app target permits cleartext LAN WebSockets
for this development proof; use WSS before any production deployment. Do not
put a personal address in committed config.

## Run the iPhone app

1. Open `ios/Memvoca/Memvoca.xcodeproj` in Xcode.
2. Select your development team and a physical iPhone.
3. Build and run; grant the Bluetooth permission when iOS asks.
4. In **Strongbox**, enter the LAN WebSocket URL, such as
   `ws://192.168.7.215:8766/stream`, then tap **Connect**.
5. Tap **Scan nearby devices**, select the DevKit 2, and inspect its GATT report.
6. Confirm the Omi audio notification, app counters, and receiver log counters
   advance together.

The app saves only the receiver URL in iOS user defaults. Its retry buffer is
memory-only and deliberately bounded; it is not a durable recovery system.

## Bluetooth permissions

The app declares the iOS Bluetooth usage description required to discover and
connect to the device. If access is denied or Bluetooth is off, the app shows
the resulting state. It never writes to the DevKit 2 in Phase 1.

## Test the receiver

```sh
cd server
python3 -m venv .venv
. .venv/bin/activate
pip install -e .
python -m unittest discover -s tests -v
```

## Roadmap

1. Omi → iPhone → Strongbox transport (current)
2. Robust live audio ingestion
3. DevKit 2 SD-card synchronization
4. Local transcription
5. Speaker diarization
6. Transcript/session storage
7. Full-text and semantic search
8. Local LLM summaries and extraction
9. Qdrant / long-term memory
10. Additional capture devices

Omi is the first device, not the whole product. Later work may add commercial
Omi support, imports, phone capture, local processing, an API, and a web UI;
none of those are included here yet.
