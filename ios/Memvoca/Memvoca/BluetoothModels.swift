import CoreBluetooth
import Foundation

struct DiscoveredDevice: Identifiable {
    let peripheral: CBPeripheral
    var rssi: Int
    var lastSeen: Date

    var id: UUID { peripheral.identifier }
    var displayName: String { peripheral.name?.isEmpty == false ? peripheral.name! : "Unnamed peripheral" }
    var isLikelyOmi: Bool { displayName.localizedCaseInsensitiveContains("omi") }
}

struct GATTCharacteristic: Identifiable {
    let serviceUUID: CBUUID
    let characteristicUUID: CBUUID
    let properties: CBCharacteristicProperties
    let descriptors: [CBDescriptor]
    let valueDescription: String?

    var id: String { "\(serviceUUID.uuidString)-\(characteristicUUID.uuidString)" }
    var propertyLabels: [String] {
        var labels: [String] = []
        if properties.contains(.read) { labels.append("read") }
        if properties.contains(.write) { labels.append("write") }
        if properties.contains(.writeWithoutResponse) { labels.append("write without response") }
        if properties.contains(.notify) { labels.append("notify") }
        if properties.contains(.indicate) { labels.append("indicate") }
        return labels.isEmpty ? ["none advertised"] : labels
    }
}

enum BluetoothStatus: Equatable {
    case starting
    case unavailable(String)
    case ready
    case scanning

    var description: String {
        switch self {
        case .starting: "Starting Bluetooth"
        case .unavailable(let reason): reason
        case .ready: "Bluetooth ready"
        case .scanning: "Scanning nearby devices"
        }
    }
}
