import SwiftUI

@main
struct MusicPlayerApp: App {
    @StateObject private var playerVM = PlayerViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(playerVM)
        }
    }
}
