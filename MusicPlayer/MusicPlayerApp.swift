import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct MusicPlayerApp: App {
    @StateObject private var playerVM      = PlayerViewModel()
    @StateObject private var themeManager  = ThemeManager()
    @StateObject private var firebase      = FirebaseManager.shared

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if firebase.isLoggedIn {
                    ContentView()
                        .environmentObject(playerVM)
                        .environmentObject(themeManager)
                        .environmentObject(firebase)
                        .task { await playerVM.loadFromFirebase() }
                } else {
                    WelcomeView()
                        .environmentObject(firebase)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: firebase.isLoggedIn)
            .onOpenURL { url in
                if url.scheme == "postor" {
                    SpotifyRemoteService.shared.handleCallback(url: url)
                } else {
                    GIDSignIn.sharedInstance.handle(url)
                }
            }
        }
    }
}
