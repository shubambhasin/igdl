import SwiftUI

@main
struct IGDLMenuBarApp: App {
    @StateObject private var manager = DownloadManager()

    var body: some Scene {
        MenuBarExtra("igdl", systemImage: "arrow.down.circle") {
            MenuBarView(manager: manager)
        }
        .menuBarExtraStyle(.window)
    }
}
