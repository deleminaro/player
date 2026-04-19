import SwiftUI

struct RecentlyPlayedView: View {
    @EnvironmentObject var playerVM: PlayerViewModel

    var body: some View {
        NavigationStack {
            Group {
                if playerVM.recentlyPlayed.isEmpty {
                    emptyState
                } else {
                    List(playerVM.recentlyPlayed) { track in
                        TrackRowView(
                            track: track,
                            isPlaying: playerVM.currentTrack?.id == track.id && playerVM.isPlaying
                        )
                        .onTapGesture { tap(track) }
                        .swipeActions(edge: .trailing) {
                            Button {
                                playerVM.addToQueue(track)
                            } label: {
                                Label("Queue", systemImage: "plus")
                            }
                            .tint(.blue)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Recently Played")
        }
    }

    private func tap(_ track: Track) {
        playerVM.addToQueue(track)
        playerVM.play(track)
        playerVM.showingNowPlaying = true
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "clock").font(.system(size: 48)).foregroundStyle(.secondary)
            Text("Nothing Played Yet").font(.title3).fontWeight(.semibold)
            Text("Tracks you play will appear here.").font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
