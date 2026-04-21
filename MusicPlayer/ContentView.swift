import SwiftUI

struct ContentView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager

    private let bg = Color(red: 0.075, green: 0.075, blue: 0.075)

    var body: some View {
        ZStack(alignment: .bottom) {
            bg.ignoresSafeArea()

            TabView {
                HomeView()
                    .tabItem { Label("Home", systemImage: "house.fill") }
                SearchView()
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }
                LibraryView()
                    .tabItem { Label("Library", systemImage: "building.columns.fill") }
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "paintpalette.fill") }
            }
            .tint(themeManager.current.primary)

            if playerVM.currentTrack != nil {
                MiniPlayerView()
                    .padding(.horizontal, 12)
                    .padding(.bottom, 58)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: playerVM.currentTrack != nil)
        .sheet(isPresented: $playerVM.showingNowPlaying) {
            NowPlayingView()
                .environmentObject(playerVM)
                .environmentObject(themeManager)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
        }
    }
}
