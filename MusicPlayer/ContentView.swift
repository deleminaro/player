import SwiftUI

struct ContentView: View {
    @EnvironmentObject var playerVM:    PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager

    @StateObject private var network = NetworkMonitor.shared
    @ObservedObject private var spotify = SpotifyService.shared

    @Environment(\.horizontalSizeClass) private var hSizeClass
    @AppStorage("spotifyOnboardingShown") private var spotifyOnboardingShown  = false
    @AppStorage("scImportOffered")        private var scImportOffered          = false
    @State private var showSpotifyOnboarding = false
    @State private var showSCImport          = false
    @State private var selectedTab: Int  = 0
    @State private var sidebarCollapsed: Bool = false

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
        .sheet(isPresented: $showSCImport) {
            SCImportView()
                .environmentObject(playerVM)
                .environmentObject(themeManager)
                .presentationDetents([.height(500)])
                .presentationDragIndicator(.hidden)
                .presentationBackground(themeManager.current.card)
                .presentationCornerRadius(28)
                .onDisappear { scImportOffered = true }
        }
        .onAppear {
            // Re-apply font appearance now that tab bar exists on screen
            themeManager.applyFontAppearance()
            if !spotifyOnboardingShown && !spotify.isAuthenticated {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showSpotifyOnboarding = true
                }
            }
            if !scImportOffered && playerVM.likedTracks.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    showSCImport = true
                }
            }
        }
        .preferredColorScheme(themeManager.current.isDark ? .dark : .light)
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

    // MARK: - iPad layout (regular) — content left, sidebar right

    private var ipadLayout: some View {
        HStack(spacing: 0) {
            // Main content
            ZStack {
                switch selectedTab {
                case 1:  SearchView()
                case 2:  WaveView()
                case 3:  LibraryView()
                case 4:  SettingsView()
                default: HomeView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Right sidebar
            ipadSidebar
        }
        .ignoresSafeArea()
    }

    private var ipadSidebar: some View {
        let collapsed = sidebarCollapsed
        let accent    = themeManager.current.primary

        return VStack(spacing: 0) {
            // Toggle button + branding
            VStack(spacing: collapsed ? 0 : 4) {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        sidebarCollapsed.toggle()
                    }
                } label: {
                    Image(systemName: collapsed ? "sidebar.right" : "sidebar.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)

                if !collapsed {
                    Text("POSTOR")
                        .font(.app(13, .black))
                        .kerning(3)
                        .foregroundStyle(accent)
                        .transition(.opacity.combined(with: .scale(scale: 0.85)))
                }
            }
            .padding(.top, 44)

            Spacer()

            // Nav buttons — vertically centred
            VStack(spacing: 6) {
                ipadNavButton("Home",     icon: "house.fill",            tag: 0)
                ipadNavButton("Search",   icon: "magnifyingglass",       tag: 1)
                ipadNavButton("Wave",     icon: "waveform",              tag: 2)
                ipadNavButton("Library",  icon: "building.columns.fill", tag: 3)
                ipadNavButton("Settings", icon: "gearshape.fill",        tag: 4)
            }
            .padding(.horizontal, collapsed ? 8 : 12)

            Spacer()
        }
        .frame(width: collapsed ? 62 : 190)
        .background(themeManager.current.card.opacity(0.6))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 1)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: collapsed)
    }

    private func ipadNavButton(_ title: String, icon: String, tag: Int) -> some View {
        let active    = selectedTab == tag
        let collapsed = sidebarCollapsed
        let accent    = themeManager.current.primary

        return Button {
            selectedTab = tag
        } label: {
            Group {
                if collapsed {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 44, height: 44)
                } else {
                    HStack(spacing: 12) {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 22)
                        Text(title)
                            .font(.app(14, .semibold))
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
            }
            .foregroundStyle(active ? accent : .white.opacity(0.45))
            .background(
                active ? accent.opacity(0.12) : Color.clear,
                in: RoundedRectangle(cornerRadius: 12)
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}
