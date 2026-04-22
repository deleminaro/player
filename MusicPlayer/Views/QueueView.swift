import SwiftUI

struct QueueView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    private var bg:     Color { themeManager.current.background }
    private var bgCard: Color { themeManager.current.card }

    var body: some View {
        NavigationStack {
            Group {
                if playerVM.queue.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(playerVM.queue) { item in
                            TrackRowView(track: item.track,
                                        isLiked: playerVM.isLiked(item.track),
                                        onToggleLike: { playerVM.toggleLike(item.track) })
                                .onTapGesture { playerVM.play(item.track) }
                                .listRowBackground(bg)
                                .listRowSeparatorTint(Color.white.opacity(0.06))
                        }
                        .onDelete(perform: playerVM.removeFromQueue)
                        .onMove(perform: playerVM.moveInQueue)
                    }
                    .listStyle(.plain)
                    .background(bg.ignoresSafeArea())
                }
            }
            .background(bg.ignoresSafeArea())
            .navigationTitle("Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(themeManager.current.primary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                        .foregroundStyle(themeManager.current.primary)
                }
            }
            .preferredColorScheme(.dark)
        }
        .presentationBackground(bg)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "list.bullet")
                .font(.system(size: 40))
                .foregroundStyle(themeManager.current.primary.opacity(0.3))
            Text("QUEUE IS EMPTY")
                .font(.system(size: 13, weight: .black)).kerning(2)
                .foregroundStyle(.white.opacity(0.45))
            Text("Add tracks from the Search tab.")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.25))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
