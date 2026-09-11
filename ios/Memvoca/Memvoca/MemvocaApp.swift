import SwiftUI

@main
struct MemvocaApp: App {
    @State private var bluetooth = BluetoothManager()

    var body: some Scene {
        WindowGroup {
            ContentView(bluetooth: bluetooth)
        }
    }
}
