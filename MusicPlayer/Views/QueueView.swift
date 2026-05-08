import SwiftUI

struct QueueView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    private var bg:     Color { themeManager.current.background }
    private var bgCard: Color { themeManager.current.card }

    private var currentIndex: Int? {
        guard let id = playerVM.currentTrack?.id else { return nil }
        return playerVM.queue.firstIndex { $0.track.id == id }
    }

    private var upcomingItems: ArraySlice<QueueItem> {
        guard let idx = currentIndex, idx + 1 < playerVM.queue.count else { return [] }
        return playerVM.queue[(idx + 1)...]
    }

    var body: some View {
        NavigationStack {
            Group {
                if playerVM.queue.isEmpty {
                    emptyState
                } else {
                    List {
                        // Now Playing
                        if let current = playerVM.currentTrack {
                            Section {
                                TrackRowView(
                                    track: current,
                                    isLiked: playerVM.isLiked(current),
                                    onToggleLike: { playerVM.toggleLike(current) }
                                )
                                .listRowBackground(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(themeManager.current.primary.opacity(0.08))
                                        .padding(.horizontal, 8)
                                )
                                .listRowSeparator(.hidden)
                            } header: {
                                Text("Now Playing")
                                    .font(themeManager.font(11, .semibold))
                                    .foregroundStyle(themeManager.current.primary)
                                    .textCase(nil)
                            }
                        }

                        // Next Up
                        if !upcomingItems.isEmpty {
                            Section {
                                ForEach(upcomingItems) { item in
                                    TrackRowView(
                                        track: item.track,
                                        isLiked: playerVM.isLiked(item.track),
                                        onToggleLike: { playerVM.toggleLike(item.track) }
                                    )
                                    .onTapGesture { playerVM.play(item.track) }
                                    .listRowBackground(bg)
                                    .listRowSeparatorTint(Color.white.opacity(0.06))
                                }
                                .onDelete { offsets in
                                    let base = (currentIndex ?? -1) + 1
                                    playerVM.removeFromQueue(at: IndexSet(offsets.map { $0 + base }))
                                }
                                .onMove { source, dest in
                                    let base = (currentIndex ?? -1) + 1
                                    let shifted = IndexSet(source.map { $0 + base })
                                    playerVM.moveInQueue(from: shifted, to: dest + base)
                                }
                            } header: {
                                Text("Next Up")
                                    .font(themeManager.font(11, .semibold))
                                    .foregroundStyle(.white.opacity(0.4))
                                    .textCase(nil)
                            }
                        } else if playerVM.currentTrack != nil {
                            Section {
                                Text("Nothing queued after this track.")
                                    .font(themeManager.font(13))
                                    .foregroundStyle(.white.opacity(0.3))
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 20)
                                    .listRowBackground(bg)
                                    .listRowSeparator(.hidden)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .background(bg.ignoresSafeArea())
                }
            }
            .background(bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Queue")
                        .font(.app(15, .bold))
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(themeManager.current.primary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                        .foregroundStyle(themeManager.current.primary)
                }
            }
            .preferredColorScheme(themeManager.current.isDark ? .dark : .light)
        }
        .presentationBackground(bg)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "list.bullet")
                .font(.app(40))
                .foregroundStyle(themeManager.current.primary.opacity(0.3))
            Text("QUEUE IS EMPTY")
                .font(.app(13, .black)).kerning(2)
                .foregroundStyle(.white.opacity(0.45))
            Text("Add tracks from the Search tab.")
                .font(.app(12))
                .foregroundStyle(.white.opacity(0.25))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
