# Omi DevKit 2 protocol status

This document distinguishes the current official source from behavior observed
with a specific physical device. It does not authorize firmware modification,
SD-card writes, or arbitrary BLE writes.

## Verified upstream facts

Verified on 2026-09-11 against the official
[BasedHardware/omi DevKit firmware](https://github.com/BasedHardware/omi/tree/main/omi/firmware/devkit):

* The audio GATT service is `19B10000-E8F2-537E-4F6C-D104768A1214`.
* Its audio-data characteristic is
  `19B10001-E8F2-537E-4F6C-D104768A1214`, with read and notify properties.
* Its codec characteristic is
  `19B10002-E8F2-537E-4F6C-D104768A1214`, with read support. The current
  DevKit 2 configuration enables the Opus codec.
* The firmware initializes Opus as 16 kHz, mono, using a 32 kbit/s VBR target.
* A BLE audio notification begins with a three-byte transport header: a
  little-endian 16-bit packet id followed by an 8-bit fragment index. The
  remaining bytes are a fragment of the encoded output; a complete encoded
  frame can span notifications.
* The DevKit 2 configuration enables offline storage, battery, button,
  speaker, USB, and haptic features. Phase 1 does not access the offline
  storage service or write to any characteristic.

The firmware comments that the audio service UUID is legacy and may change.
Memvoca verifies both service and characteristic UUIDs in the connected GATT
database before it enables notifications.

## Observed behavior

No physical DevKit 2 observations have been recorded in this repository yet.
Use the app's GATT report and packet counters to add device-specific results
here, including firmware revision, codec-byte value, and actual notification
sizes.

## Unknown or intentionally unimplemented

* The exact on-device SD-card synchronization protocol and its safe read-only
  workflow.
* Whether all released DevKit 2 firmware versions use the same packet framing.
* A public compatibility commitment for the legacy audio UUID.
* Audio reassembly, decoding, and durable recovery semantics.
