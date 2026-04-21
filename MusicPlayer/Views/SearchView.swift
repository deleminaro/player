import SwiftUI

struct SearchView: View {
    @EnvironmentObject var playerVM: PlayerViewModel

    @State private var query       = ""
    @State private var results:    [Track] = []
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var focused: Bool

    private let bg      = Color(red: 0.075, green: 0.075, blue: 0.075)
    private let bgCard  = Color(red: 0.110, green: 0.110, blue: 0.110)
    private let primary = Color(red: 0.753, green: 0.757, blue: 1.0)

    var body: some View {
        NavigationStack {
            ZStack {
                bg.ignoresSafeArea()

                Group {
                    if isSearching {
                        ProgressView()
                            .tint(primary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let err = searchError {
                        errorState(err)
                    } else if !results.isEmpty {
                        resultsList
                    } else if query.isEmpty {
                        recentSearchesView
                    } else {
                        emptyResults
                    }
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(bg, for: .navigationBar)
            .preferredColorScheme(.dark)
            // Bottom search bar — sits above the tab bar
            .safeAreaInset(edge: .bottom) {
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(bg)
                    // extra room when mini player is visible
                    .padding(.bottom, playerVM.currentTrack != nil ? 64 : 0)
            }
        }
        .onTapGesture { focused = false }
    }

    // MARK: - Bottom search bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(primary)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))

                TextField("", text: $query,
                          prompt: Text("Artists, Songs, Lyrics, and More")
                            .foregroundStyle(.white.opacity(0.35))
                            .font(.system(size: 14)))
                    .foregroundStyle(.white)
                    .font(.system(size: 14))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($focused)
                    .onSubmit { commitSearch() }
                    .onChange(of: query) { _, new in scheduleSearch(new) }

                if !query.isEmpty {
                    Button { query = ""; results = []; searchError = nil } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

            Image(systemName: "mic.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    // MARK: - Recent searches

    private var recentSearchesView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                if !playerVM.recentSearches.isEmpty {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.35))
                            Text("RECENT SEARCHES")
                                .font(.system(size: 9, weight: .black)).kerning(1.5)
                                .foregroundStyle(.white.opacity(0.35))
                        }
                        Spacer()
                        Button { playerVM.clearRecentSearches() } label: {
                            Text("CLEAR")
                                .font(.system(size: 9, weight: .black)).kerning(1)
                                .foregroundStyle(primary)
                        }
                    }
                    .padding(.horizontal, 16)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(playerVM.recentSearches, id: \.self) { s in
                                Button {
                                    query = s; commitSearch()
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.up.left")
                                            .font(.system(size: 9))
                                            .foregroundStyle(.white.opacity(0.35))
                                        Text(s)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(.white.opacity(0.7))
                                    }
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(Color.white.opacity(0.07), in: Capsule())
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 44))
                            .foregroundStyle(primary.opacity(0.25))
                        Text("SEARCH MUSIC")
                            .font(.system(size: 13, weight: .black)).kerning(2)
                            .foregroundStyle(.white.opacity(0.4))
                        Text("Songs, artists, playlists and more.")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.25))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 120)
        }
    }

    // MARK: - Results list

    private var resultsList: some View {
        List(results) { track in
            TrackRowView(track: track)
                .environmentObject(playerVM)
                .onTapGesture { tap(track) }
                .swipeActions(edge: .trailing) {
                    Button { playerVM.addToQueue(track) } label: {
                        Label("Queue", systemImage: "plus")
                    }
                    .tint(primary)
                    Button {
                        playerVM.toggleLike(track)
                    } label: {
                        Label(playerVM.isLiked(track) ? "Unlike" : "Like",
                              systemImage: playerVM.isLiked(track) ? "heart.slash" : "heart")
                    }
                    .tint(.pink)
                }
                .listRowBackground(bg)
                .listRowSeparatorTint(Color.white.opacity(0.06))
        }
        .listStyle(.plain)
    }

    // MARK: - States

    private var emptyResults: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36)).foregroundStyle(primary.opacity(0.3))
            Text("NO RESULTS")
                .font(.system(size: 13, weight: .black)).kerning(2)
                .foregroundStyle(.white.opacity(0.4))
            Text("Try a different search term.")
                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.25))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(_ msg: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36)).foregroundStyle(.orange.opacity(0.6))
            Text("SEARCH FAILED")
                .font(.system(size: 13, weight: .black)).kerning(2)
                .foregroundStyle(.white.opacity(0.4))
            Text(msg).font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.25)).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    // MARK: - Helpers

    private func tap(_ track: Track) {
        playerVM.addToQueue(track)
        playerVM.play(track)
        playerVM.showingNowPlaying = true
    }

    private func commitSearch() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        playerVM.addRecentSearch(q)
        Task { await performSearch(q) }
    }

    private func scheduleSearch(_ q: String) {
        searchTask?.cancel()
        searchError = nil
        guard !q.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []; return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
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
}
