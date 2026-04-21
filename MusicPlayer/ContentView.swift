import SwiftUI

struct ContentView: View {
    @EnvironmentObject var playerVM: PlayerViewModel

    private let bg      = Color(red: 0.075, green: 0.075, blue: 0.075)
    private let primary = Color(red: 0.753, green: 0.757, blue: 1.0)

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
            }
            .tint(primary)

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
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
        }
    }
}
