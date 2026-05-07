import SwiftUI

struct ContentView: View {
    @EnvironmentObject var playerVM:    PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager

    @StateObject private var network = NetworkMonitor.shared
    @ObservedObject private var spotify = SpotifyService.shared

    @Environment(\.horizontalSizeClass) private var hSizeClass
    @AppStorage("spotifyOnboardingShown") private var spotifyOnboardingShown = false
    @State private var showSpotifyOnboarding = false
    @State private var selectedTab: Int? = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            if hSizeClass == .regular {
                ipadLayout
            } else {
                iphoneLayout
            }

            if playerVM.currentTrack != nil {
                MiniPlayerView()
                    .padding(.horizontal, 12)
                    .padding(.bottom, hSizeClass == .regular ? 12 : 58)
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
                    Text("No Internet Connection").font(.app(13, .semibold))
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

    // MARK: - iPhone layout (compact)

    private var iphoneLayout: some View {
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
    }

    // MARK: - iPad layout (regular)

    private var ipadLayout: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                sidebarItem("Home",    icon: "house.fill",             tag: 0)
                sidebarItem("Search",  icon: "magnifyingglass",        tag: 1)
                sidebarItem("Wave",    icon: "waveform",               tag: 2)
                sidebarItem("Library", icon: "building.columns.fill",  tag: 3)
                sidebarItem("Settings",icon: "gearshape.fill",         tag: 4)
            }
            .listStyle(.sidebar)
            .navigationTitle("POSTOR")
            .navigationBarTitleDisplayMode(.large)
            .background(themeManager.current.background)
            .scrollContentBackground(.hidden)
        } detail: {
            switch selectedTab ?? 0 {
            case 1:  SearchView()
            case 2:  WaveView()
            case 3:  LibraryView()
            case 4:  SettingsView()
            default: HomeView()
            }
        }
        .tint(themeManager.current.primary)
    }

    private func sidebarItem(_ title: String, icon: String, tag: Int) -> some View {
        Label(title, systemImage: icon)
            .font(.app(15, .semibold))
            .tag(tag)
    }
}
