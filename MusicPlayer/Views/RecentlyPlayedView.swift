import SwiftUI

struct RecentlyPlayedView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    private var bg: Color { themeManager.current.background }

    var body: some View {
        NavigationStack {
            Group {
                if playerVM.recentlyPlayed.isEmpty {
                    emptyState
                } else {
                    List(playerVM.recentlyPlayed) { track in
                        TrackRowView(track: track,
                                    isLiked: playerVM.isLiked(track),
                                    onToggleLike: { playerVM.toggleLike(track) })
                            .onTapGesture { tap(track) }
                            .swipeActions(edge: .trailing) {
                                Button { playerVM.addToQueue(track) } label: {
                                    Label("Queue", systemImage: "plus")
                                }
                                .tint(themeManager.current.primary)
                            }
                            .listRowBackground(bg)
                            .listRowSeparatorTint(Color.white.opacity(0.06))
                    }
                    .listStyle(.plain)
                }
            }
            .background(bg.ignoresSafeArea())
            .navigationTitle("Recently Played")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.app(13, .bold))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
        .presentationBackground(bg)
    }

    private func tap(_ track: Track) {
        playerVM.playFromList(playerVM.recentlyPlayed, startingWith: track)
        playerVM.showingNowPlaying = true
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "clock")
                .font(.app(40))
                .foregroundStyle(themeManager.current.primary.opacity(0.3))
            Text("NOTHING PLAYED YET")
                .font(.app(13, .black)).kerning(2)
                .foregroundStyle(.white.opacity(0.45))
            Text("Tracks you play will appear here.")
                .font(.app(12))
                .foregroundStyle(.white.opacity(0.25))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
