import Foundation
import Observation

enum StrongboxStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case unavailable(String)

    var description: String {
        switch self {
        case .disconnected: "Disconnected"
        case .connecting: "Connecting"
        case .connected: "Connected"
        case .unavailable(let reason): reason
        }
    }
}

@Observable
@MainActor
final class StrongboxManager {
    private let defaultURL = "ws://192.168.7.215:8766/stream"
    private let bufferLimit = 256
    private var task: URLSessionWebSocketTask?
    private var reconnectTask: Task<Void, Never>?
    private var sequence = 0
    private var buffer: [AudioPacket] = []

    var serverURL: String {
        didSet { UserDefaults.standard.set(serverURL, forKey: "strongboxURL") }
    }
    private(set) var status: StrongboxStatus = .disconnected
    private(set) var packetsForwarded = 0
    private(set) var bytesForwarded = 0
    private(set) var bufferedPacketCount = 0
    private(set) var droppedPacketCount = 0
    private(set) var lastSuccessfulSend: Date?
    private(set) var diagnosticMessage = "Configure a receiver URL, then connect."

    init() {
        serverURL = UserDefaults.standard.string(forKey: "strongboxURL") ?? defaultURL
    }

    func connect() {
        reconnectTask?.cancel()
        guard let url = URL(string: serverURL), ["ws", "wss"].contains(url.scheme?.lowercased() ?? "") else {
            status = .unavailable("Enter a valid ws:// or wss:// receiver URL.")
            return
        }
        task?.cancel(with: .goingAway, reason: nil)
        status = .connecting
        diagnosticMessage = "Connecting to \(url.host ?? "receiver")."
        let newTask = URLSession.shared.webSocketTask(with: url)
        task = newTask
        newTask.resume()
        newTask.sendPing { [weak self] error in
            Task { @MainActor in
                guard self?.task === newTask else { return }
                if let error {
                    self?.connectionFailed(error)
                } else {
                    self?.status = .connected
                    self?.diagnosticMessage = "Connected; forwarding buffered packets."
                    self?.flushBuffer()
                    self?.receiveStatus(from: newTask)
                }
            }
        }
    }

    func disconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
        status = .disconnected
        diagnosticMessage = "Disconnected from Strongbox."
    }

    func forward(_ packet: AudioPacket) {
        guard status == .connected else {
            enqueue(packet)
            if status == .disconnected || isUnavailable { connect() }
            return
        }
        send(packet)
    }

    private var isUnavailable: Bool {
        if case .unavailable = status { return true }
        return false
    }

    private func enqueue(_ packet: AudioPacket) {
        if buffer.count == bufferLimit {
            buffer.removeFirst()
            droppedPacketCount += 1
        }
        buffer.append(packet)
        bufferedPacketCount = buffer.count
    }

    private func flushBuffer() {
        while !buffer.isEmpty, status == .connected {
            send(buffer.removeFirst())
        }
        bufferedPacketCount = buffer.count
    }

    private func send(_ packet: AudioPacket) {
        guard let task else { enqueue(packet); return }
        sequence += 1
        let metadata: [String: Any] = [
            "type": "packet",
            "device_id": packet.deviceID.uuidString,
            "session_id": sessionID(for: packet.deviceID),
            "sequence": sequence,
            "timestamp": ISO8601DateFormatter().string(from: packet.receivedAt),
            "codec": OmiDevKit2Protocol.codec,
            "sample_rate": OmiDevKit2Protocol.sampleRate,
            "channels": OmiDevKit2Protocol.channels,
            "payload_layout": OmiDevKit2Protocol.payloadLayout,
        ]
        guard let metadataData = try? JSONSerialization.data(withJSONObject: metadata),
              let metadataText = String(data: metadataData, encoding: .utf8) else {
            diagnosticMessage = "Could not encode packet metadata."
            return
        }
        task.send(.string(metadataText)) { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                if let error { self.connectionFailed(error); self.enqueue(packet); return }
                task.send(.data(packet.payload)) { [weak self] error in
                    Task { @MainActor in
                        guard let self else { return }
                        if let error { self.connectionFailed(error); self.enqueue(packet); return }
                        self.packetsForwarded += 1
                        self.bytesForwarded += packet.payload.count
                        self.lastSuccessfulSend = Date()
                    }
                }
            }
        }
    }

    private func sessionID(for deviceID: UUID) -> String {
        "\(deviceID.uuidString)-\(Calendar.current.component(.weekOfYear, from: Date()))"
    }

    private func receiveStatus(from task: URLSessionWebSocketTask) {
        task.receive { [weak self] result in
            Task { @MainActor in
                guard self?.task === task else { return }
                if case .failure(let error) = result { self?.connectionFailed(error); return }
                self?.receiveStatus(from: task)
            }
        }
    }

    private func connectionFailed(_ error: Error) {
        task = nil
        status = .unavailable("Receiver unavailable: \(error.localizedDescription)")
        diagnosticMessage = "Retrying shortly; packets are buffered in memory."
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.connect()
        }
    }
}
