import SwiftUI

struct ContentView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                HomeView()
                    .tabItem { Label("Home", systemImage: "house.fill") }
                SearchView()
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }
                LibraryView()
                    .tabItem { Label("Library", systemImage: "building.columns.fill") }
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
            }
            .tint(themeManager.current.primary)

            if playerVM.currentTrack != nil {
                MiniPlayerView()
                    .padding(.horizontal, 12)
                    .padding(.bottom, 58)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background {
            ZStack {
                themeManager.current.background
                if themeManager.backgroundStyle == .customPhoto,
                   let wallpaper = themeManager.customWallpaper {
                    Image(uiImage: wallpaper)
                        .resizable()
                        .scaledToFill()
                        .overlay(Color.black.opacity(0.55))
                }
            }
            .ignoresSafeArea()
        }
        .fontDesign(themeManager.appFont.fontDesign)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: playerVM.currentTrack != nil)
        .fullScreenCover(isPresented: $playerVM.showingNowPlaying) {
            NowPlayingView()
                .environmentObject(playerVM)
                .environmentObject(themeManager)
        }
    }
}
