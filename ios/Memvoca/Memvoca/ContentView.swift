import SwiftUI

struct ContentView: View {
    let bluetooth: BluetoothManager
    let strongbox: StrongboxManager

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

                Section("Omi audio") {
                    LabeledContent("Notifications", value: bluetooth.audioNotificationsActive ? "Active" : "Inactive")
                    LabeledContent("Packets received", value: "\(bluetooth.audioPacketsReceived)")
                    LabeledContent("Bytes received", value: "\(bluetooth.audioBytesReceived)")
                    Text("Only the verified DevKit 2 audio characteristic is subscribed. Its raw BLE payload is forwarded unchanged.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Strongbox") {
                    TextField("WebSocket URL", text: Bindable(strongbox).serverURL)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .font(.caption)
                    HStack {
                        Circle().fill(strongbox.status == .connected ? .green : .orange).frame(width: 10, height: 10)
                        Text(strongbox.status.description).font(.headline)
                        Spacer()
                        Button(strongbox.status == .connected ? "Disconnect" : "Connect") {
                            strongbox.status == .connected ? strongbox.disconnect() : strongbox.connect()
                        }
                    }
                    Text(strongbox.diagnosticMessage).font(.caption).foregroundStyle(.secondary)
                    LabeledContent("Packets forwarded", value: "\(strongbox.packetsForwarded)")
                    LabeledContent("Bytes forwarded", value: "\(strongbox.bytesForwarded)")
                    LabeledContent("Buffered packets", value: "\(strongbox.bufferedPacketCount)")
                    LabeledContent("Dropped (buffer full)", value: "\(strongbox.droppedPacketCount)")
                    if let lastSuccessfulSend = strongbox.lastSuccessfulSend {
                        LabeledContent("Last successful send", value: lastSuccessfulSend.formatted(date: .omitted, time: .standard))
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
