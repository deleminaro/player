import SwiftUI

@main
struct MusicPlayerApp: App {
    @StateObject private var playerVM    = PlayerViewModel()
    @StateObject private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(playerVM)
                .environmentObject(themeManager)
        }
    }
}
