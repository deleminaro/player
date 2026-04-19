import SwiftUI

struct ContentView: View {
    @EnvironmentObject var playerVM: PlayerViewModel

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                SearchView()
                    .tabItem { Label("Search",  systemImage: "magnifyingglass") }

                RecentlyPlayedView()
                    .tabItem { Label("Recent",  systemImage: "clock") }

                QueueView()
                    .tabItem { Label("Queue",   systemImage: "list.bullet") }
            }

            // Mini-player floats above tab bar when something is loaded
            if playerVM.currentTrack != nil {
                MiniPlayerView()
                    .padding(.bottom, 49)          // height of default tab bar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: playerVM.currentTrack != nil)
        .fullScreenCover(isPresented: $playerVM.showingNowPlaying) {
            NowPlayingView()
                .environmentObject(playerVM)
        }
    }
}
