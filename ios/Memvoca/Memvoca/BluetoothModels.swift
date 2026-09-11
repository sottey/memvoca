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

struct AudioPacket {
    let deviceID: UUID
    let payload: Data
    let receivedAt: Date
}

enum OmiDevKit2Protocol {
    static let audioServiceUUID = "19B10000-E8F2-537E-4F6C-D104768A1214"
    static let audioDataUUID = "19B10001-E8F2-537E-4F6C-D104768A1214"
    static let audioCodecUUID = "19B10002-E8F2-537E-4F6C-D104768A1214"
    static let codec = "opus"
    static let sampleRate = 16_000
    static let channels = 1
    static let payloadLayout = "omi-devkit2: little-endian uint16 packet id, uint8 fragment index, encoded opus fragment"

    static func isAudioService(_ uuid: CBUUID) -> Bool {
        uuid.uuidString.caseInsensitiveCompare(audioServiceUUID) == .orderedSame
    }

    static func isAudioData(_ uuid: CBUUID) -> Bool {
        uuid.uuidString.caseInsensitiveCompare(audioDataUUID) == .orderedSame
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
