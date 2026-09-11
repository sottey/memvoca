import SwiftUI

@main
struct MemvocaApp: App {
    @State private var bluetooth = BluetoothManager()
    @State private var strongbox = StrongboxManager()

    var body: some Scene {
        WindowGroup {
            ContentView(bluetooth: bluetooth, strongbox: strongbox)
                .onAppear { bluetooth.setAudioPacketHandler(strongbox.forward) }
        }
    }
}
