import CoreBluetooth
import Foundation
import Observation

@Observable
final class BluetoothManager: NSObject {
    private var central: CBCentralManager!
    private var devicesByID: [UUID: DiscoveredDevice] = [:]
    private var audioPacketHandler: ((AudioPacket) -> Void)?

    private(set) var status: BluetoothStatus = .starting
    private(set) var devices: [DiscoveredDevice] = []
    private(set) var connectedDevice: DiscoveredDevice?
    private(set) var gattCharacteristics: [GATTCharacteristic] = []
    private(set) var diagnosticMessage = "Waiting for Bluetooth state."
    private(set) var audioNotificationsActive = false
    private(set) var audioPacketsReceived = 0
    private(set) var audioBytesReceived = 0

    func setAudioPacketHandler(_ handler: @escaping (AudioPacket) -> Void) {
        audioPacketHandler = handler
    }

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func startScan() {
        guard central.state == .poweredOn else {
            diagnosticMessage = "Bluetooth is not available: \(stateDescription(central.state))."
            return
        }
        devicesByID.removeAll()
        devices.removeAll()
        gattCharacteristics.removeAll()
        audioNotificationsActive = false
        audioPacketsReceived = 0
        audioBytesReceived = 0
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        status = .scanning
        diagnosticMessage = "Scanning all nearby BLE peripherals."
    }

    func stopScan() {
        central.stopScan()
        if central.state == .poweredOn { status = .ready }
    }

    func connect(to device: DiscoveredDevice) {
        stopScan()
        gattCharacteristics.removeAll()
        audioNotificationsActive = false
        diagnosticMessage = "Connecting to \(device.displayName)."
        central.connect(device.peripheral)
    }

    func disconnect() {
        guard let peripheral = connectedDevice?.peripheral else { return }
        central.cancelPeripheralConnection(peripheral)
    }

    private func refreshDevices() {
        devices = devicesByID.values.sorted { lhs, rhs in
            if lhs.isLikelyOmi != rhs.isLikelyOmi { return lhs.isLikelyOmi }
            return lhs.rssi > rhs.rssi
        }
    }

    private func stateDescription(_ state: CBManagerState) -> String {
        switch state {
        case .unknown: "Bluetooth state is unknown"
        case .resetting: "Bluetooth is resetting"
        case .unsupported: "Bluetooth is unsupported on this device"
        case .unauthorized: "Bluetooth permission was denied"
        case .poweredOff: "Bluetooth is turned off"
        case .poweredOn: "Bluetooth is on"
        @unknown default: "Bluetooth returned an unknown state"
        }
    }
}

extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            status = .ready
            diagnosticMessage = "Bluetooth is ready. Tap Scan nearby devices to begin."
        } else {
            status = .unavailable(stateDescription(central.state))
            diagnosticMessage = stateDescription(central.state)
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        devicesByID[peripheral.identifier] = DiscoveredDevice(peripheral: peripheral, rssi: RSSI.intValue, lastSeen: Date())
        refreshDevices()
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard let device = devicesByID[peripheral.identifier] else { return }
        connectedDevice = device
        peripheral.delegate = self
        diagnosticMessage = "Connected. Discovering GATT services."
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        diagnosticMessage = "Could not connect to \(peripheral.name ?? peripheral.identifier.uuidString): \(error?.localizedDescription ?? "no error details")."
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectedDevice = nil
        audioNotificationsActive = false
        diagnosticMessage = "Disconnected from \(peripheral.name ?? peripheral.identifier.uuidString).\(error.map { " \($0.localizedDescription)" } ?? "")"
    }
}

extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error { diagnosticMessage = "Service discovery failed: \(error.localizedDescription)"; return }
        let services = peripheral.services ?? []
        diagnosticMessage = "Found \(services.count) service(s); discovering characteristics."
        services.forEach { peripheral.discoverCharacteristics(nil, for: $0) }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error { diagnosticMessage = "Characteristic discovery failed for \(service.uuid.uuidString): \(error.localizedDescription)"; return }
        for characteristic in service.characteristics ?? [] {
            gattCharacteristics.removeAll { $0.serviceUUID == service.uuid && $0.characteristicUUID == characteristic.uuid }
            gattCharacteristics.append(GATTCharacteristic(serviceUUID: service.uuid, characteristicUUID: characteristic.uuid, properties: characteristic.properties, descriptors: [], valueDescription: nil))
            peripheral.discoverDescriptors(for: characteristic)
            if characteristic.properties.contains(.read) { peripheral.readValue(for: characteristic) }
            if OmiDevKit2Protocol.isAudioService(service.uuid),
               OmiDevKit2Protocol.isAudioData(characteristic.uuid),
               characteristic.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: characteristic)
                diagnosticMessage = "Verified DevKit 2 audio characteristic found; enabling notifications."
            }
        }
        diagnosticMessage = "GATT discovery complete: \(gattCharacteristics.count) characteristic(s). Readable values are being requested."
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let service = characteristic.service else { return }
        updateCharacteristic(serviceUUID: service.uuid, characteristic: characteristic)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let service = characteristic.service else { return }
        if OmiDevKit2Protocol.isAudioService(service.uuid),
           OmiDevKit2Protocol.isAudioData(characteristic.uuid),
           error == nil,
           let data = characteristic.value,
           !data.isEmpty {
            audioPacketsReceived += 1
            audioBytesReceived += data.count
            audioPacketHandler?(AudioPacket(deviceID: peripheral.identifier, payload: data, receivedAt: Date()))
            return
        }
        let value: String
        if let error { value = "Read error: \(error.localizedDescription)" }
        else if let data = characteristic.value { value = data.map { String(format: "%02X", $0) }.joined(separator: " ") }
        else { value = "No value returned" }
        updateCharacteristic(serviceUUID: service.uuid, characteristic: characteristic, valueDescription: value)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard let service = characteristic.service,
              OmiDevKit2Protocol.isAudioService(service.uuid),
              OmiDevKit2Protocol.isAudioData(characteristic.uuid) else { return }
        if let error {
            audioNotificationsActive = false
            diagnosticMessage = "Could not enable DevKit 2 audio notifications: \(error.localizedDescription)"
        } else {
            audioNotificationsActive = characteristic.isNotifying
            diagnosticMessage = characteristic.isNotifying ? "Receiving verified DevKit 2 audio notifications." : "DevKit 2 audio notifications stopped."
        }
    }

    private func updateCharacteristic(serviceUUID: CBUUID, characteristic: CBCharacteristic, valueDescription: String? = nil) {
        guard let index = gattCharacteristics.firstIndex(where: { $0.serviceUUID == serviceUUID && $0.characteristicUUID == characteristic.uuid }) else { return }
        let current = gattCharacteristics[index]
        gattCharacteristics[index] = GATTCharacteristic(serviceUUID: serviceUUID, characteristicUUID: characteristic.uuid, properties: characteristic.properties, descriptors: characteristic.descriptors ?? [], valueDescription: valueDescription ?? current.valueDescription)
    }
}
