import SwiftUI

struct ContentView: View {
    @EnvironmentObject var playerVM:    PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager

    @StateObject private var network = NetworkMonitor.shared
    @ObservedObject private var spotify = SpotifyService.shared

    @AppStorage("spotifyOnboardingShown") private var spotifyOnboardingShown = false
    @State private var showSpotifyOnboarding = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                HomeView()
                    .tabItem { Label("Home", systemImage: "house.fill") }
                SearchView()
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }
                WaveView()
                    .tabItem { Label("Wave", systemImage: "waveform") }
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
        // No-internet banner
        .overlay(alignment: .top) {
            if !network.isConnected {
                HStack(spacing: 8) {
                    Image(systemName: "wifi.slash").font(.system(size: 12, weight: .semibold))
                    Text("No Internet Connection").font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20).padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.top, 56)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4), value: network.isConnected)
        .fullScreenCover(isPresented: $playerVM.showingNowPlaying) {
            NowPlayingView()
                .environmentObject(playerVM)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showSpotifyOnboarding) {
            SpotifyOnboardingSheet()
                .environmentObject(themeManager)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(Color(red: 0.07, green: 0.07, blue: 0.07))
                .presentationCornerRadius(28)
                .onDisappear { spotifyOnboardingShown = true }
        }
        .onAppear {
            if !spotifyOnboardingShown && !spotify.isAuthenticated {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showSpotifyOnboarding = true
                }
            }
        }
    }
}
