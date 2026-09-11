import SwiftUI

struct ContentView: View {
    let bluetooth: BluetoothManager

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Circle().fill(statusColor).frame(width: 10, height: 10); Text(bluetooth.status.description).font(.headline) }
                        Text(bluetooth.diagnosticMessage).font(.subheadline).foregroundStyle(.secondary)
                        Button(bluetooth.status == .scanning ? "Stop scanning" : "Scan nearby devices") {
                            bluetooth.status == .scanning ? bluetooth.stopScan() : bluetooth.startScan()
                        }.buttonStyle(.borderedProminent).tint(.indigo)
                    }.padding(.vertical, 6)
                } header: { Text("Bluetooth") }

                Section("Nearby devices") {
                    if bluetooth.devices.isEmpty { Text("No devices discovered yet.").foregroundStyle(.secondary) }
                    ForEach(bluetooth.devices) { device in
                        Button { bluetooth.connect(to: device) } label: {
                            HStack {
                                VStack(alignment: .leading) { Text(device.displayName).fontWeight(device.isLikelyOmi ? .semibold : .regular); Text(device.id.uuidString).font(.caption2).foregroundStyle(.secondary) }
                                Spacer(); VStack(alignment: .trailing) { if device.isLikelyOmi { Text("Likely Omi").font(.caption).foregroundStyle(.indigo) }; Text("\(device.rssi) dBm").font(.caption).foregroundStyle(.secondary) }
                            }
                        }.disabled(bluetooth.connectedDevice != nil)
                    }
                }

                if let device = bluetooth.connectedDevice {
                    Section("Connected device") {
                        LabeledContent("Name", value: device.displayName)
                        LabeledContent("Identifier", value: device.id.uuidString).font(.caption)
                        Button("Disconnect", role: .destructive) { bluetooth.disconnect() }
                    }
                    Section("GATT report") {
                        if bluetooth.gattCharacteristics.isEmpty { Text("Discovering services and characteristics…").foregroundStyle(.secondary) }
                        ForEach(bluetooth.gattCharacteristics) { characteristic in
                            DisclosureGroup {
                                Text("Service: \(characteristic.serviceUUID.uuidString)").font(.caption).textSelection(.enabled)
                                Text("Properties: \(characteristic.propertyLabels.joined(separator: ", "))").font(.caption)
                                Text("Descriptors: \(characteristic.descriptors.map { $0.uuid.uuidString }.joined(separator: ", ").ifEmpty("none"))").font(.caption)
                                if let value = characteristic.valueDescription { Text("Read value: \(value)").font(.caption).textSelection(.enabled) }
                            } label: { Text(characteristic.characteristicUUID.uuidString).font(.system(.body, design: .monospaced)) }
                        }
                    }
                }
            }
            .navigationTitle("Memvoca")
        }
    }

    private var statusColor: Color {
        switch bluetooth.status { case .ready: .green; case .scanning: .indigo; case .starting: .orange; case .unavailable: .red }
    }
}

private extension String {
    func ifEmpty(_ replacement: String) -> String { isEmpty ? replacement : self }
}
