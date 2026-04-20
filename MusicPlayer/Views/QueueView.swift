import SwiftUI

struct QueueView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if playerVM.queue.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(playerVM.queue) { item in
                            TrackRowView(track: item.track)
                            .onTapGesture { playerVM.play(item.track) }
                        }
                        .onDelete(perform: playerVM.removeFromQueue)
                        .onMove(perform: playerVM.moveInQueue)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "list.bullet").font(.system(size: 48)).foregroundStyle(.secondary)
            Text("Queue is Empty").font(.title3).fontWeight(.semibold)
            Text("Add tracks from the Search tab.").font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
