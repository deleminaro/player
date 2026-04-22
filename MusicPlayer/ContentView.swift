import SwiftUI

struct ContentView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        ZStack(alignment: .bottom) {
            themeManager.current.background.ignoresSafeArea()

            // Custom wallpaper fills the whole app when selected
            if themeManager.backgroundStyle == .customPhoto,
               let wallpaper = themeManager.customWallpaper {
                Image(uiImage: wallpaper)
                    .resizable().aspectRatio(contentMode: .fill)
                    .clipped()
                    .ignoresSafeArea()
                    .overlay(Color.black.opacity(0.55).ignoresSafeArea())
            }

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
