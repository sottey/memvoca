# Memvoca

Memvoca is a privacy-first, self-hosted ambient-audio memory platform. Its
first capture path is an Omi DevKit 2 connected by Bluetooth LE to an iPhone;
the iPhone forwards data to a self-hosted Strongbox receiver. The Mac is only
used for development.

## Current status

Phase 1A is in progress. The iOS app discovers BLE peripherals, makes devices
whose names contain `Omi` easy to spot, connects to a selected device, and
safely reports its GATT services, characteristics, descriptor UUIDs, and
readable values. It never writes to a BLE characteristic.

The next step is to verify the DevKit 2 protocol against official upstream
Omi/BasedHardware material before enabling any audio notification.

## Run the iOS discovery app

1. Open `ios/Memvoca/Memvoca.xcodeproj` in Xcode.
2. Select your development team and a physical iPhone. CoreBluetooth scanning
   does not work in the iOS Simulator.
3. Build and run, allow Bluetooth access, then tap **Scan nearby devices**.

No Omi cloud account or Omi cloud service is used.
Omi self hosted solution
