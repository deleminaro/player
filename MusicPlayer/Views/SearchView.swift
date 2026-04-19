import SwiftUI

struct SearchView: View {
    @EnvironmentObject var playerVM: PlayerViewModel

    @State private var query        = ""
    @State private var results:     [Track] = []
    @State private var isSearching  = false
    @State private var searchError: String?
    @State private var searchTask:  Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Group {
                if isSearching {
                    ProgressView("Searching…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = searchError {
                    emptyState(icon: "exclamationmark.circle",
                               title: "Search Failed",
                               message: err)
                } else if results.isEmpty && !query.isEmpty {
                    emptyState(icon: "magnifyingglass",
                               title: "No Results",
                               message: "Try a different search term.")
                } else if query.isEmpty {
                    emptyState(icon: "music.note.list",
                               title: "Find Music",
                               message: "Search for songs, artists, or playlists.")
                } else {
                    List(results) { track in
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
            .navigationTitle("Search")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Artists, songs…")
            .onChange(of: query) { _, new in
                scheduleSearch(new)
            }
        }
    }

    // MARK: - Helpers

    private func tap(_ track: Track) {
        playerVM.addToQueue(track)
        playerVM.play(track)
        playerVM.showingNowPlaying = true
    }

    private func scheduleSearch(_ q: String) {
        searchTask?.cancel()
        searchError = nil
        guard !q.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []; return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)   // 400 ms debounce
            guard !Task.isCancelled else { return }
            await performSearch(q)
        }
    }

    private func performSearch(_ q: String) async {
        isSearching = true
        defer { isSearching = false }
        do {
            let tracks = try await SoundCloudService.shared.search(query: q)
            guard !Task.isCancelled else { return }
            results = tracks
        } catch {
            searchError = error.localizedDescription
        }
    }

    @ViewBuilder
    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(title).font(.title3).fontWeight(.semibold)
            Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
