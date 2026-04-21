import SwiftUI

private enum SearchFilter: String, CaseIterable {
    case all       = "All"
    case tracks    = "Tracks"
    case playlists = "Playlists"
    case albums    = "Albums"
    case artists   = "Artists"

    var icon: String {
        switch self {
        case .all:       return "square.grid.2x2"
        case .tracks:    return "music.note"
        case .playlists: return "music.note.list"
        case .albums:    return "opticaldisc"
        case .artists:   return "person.2"
        }
    }
}

struct SearchView: View {
    @EnvironmentObject var playerVM: PlayerViewModel

    @State private var query        = ""
    @State private var results:     [Track] = []
    @State private var isSearching  = false
    @State private var isLoadingMore = false
    @State private var searchError: String?
    @State private var searchTask:  Task<Void, Never>?
    @State private var filter       = SearchFilter.all
    @State private var currentQuery = ""
    @FocusState private var focused: Bool

    private let bg      = Color(red: 0.075, green: 0.075, blue: 0.075)
    private let bgField = Color(red: 0.14,  green: 0.14,  blue: 0.14)
    private let primary = Color(red: 0.753, green: 0.757, blue: 1.0)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ── Search bar ───────────────────────────────────────────
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))

                    TextField("", text: $query,
                              prompt: Text("Artists, Songs, Lyrics, and More")
                                .foregroundStyle(.white.opacity(0.35))
                                .font(.system(size: 15)))
                        .foregroundStyle(.white)
                        .font(.system(size: 15))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($focused)
                        .onSubmit { commitSearch() }
                        .onChange(of: query) { _, new in scheduleSearch(new) }

                    if !query.isEmpty {
                        Button {
                            query = ""; results = []; searchError = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.white.opacity(0.4))
                                .font(.system(size: 16))
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 13)
                .background(bgField, in: Capsule())
                .padding(.horizontal, 16)
                .padding(.top, 12).padding(.bottom, 14)

                // ── Filter chips ─────────────────────────────────────────
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(SearchFilter.allCases, id: \.self) { f in
                            Button { withAnimation(.easeInOut(duration: 0.18)) { filter = f } } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: f.icon)
                                        .font(.system(size: 12, weight: .semibold))
                                    Text(f.rawValue)
                                        .font(.system(size: 13, weight: .bold))
                                }
                                .foregroundStyle(filter == f ? .black : .white)
                                .padding(.horizontal, 16).padding(.vertical, 10)
                                .background(
                                    Capsule().fill(filter == f ? .white : bgField)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 12)

                Divider().background(Color.white.opacity(0.06))

                // ── Content ───────────────────────────────────────────────
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
            .background(bg.ignoresSafeArea())
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(bg, for: .navigationBar)
            .preferredColorScheme(.dark)
        }
        .onTapGesture { focused = false }
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
                                    .background(bgField, in: Capsule())
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
        List {
            ForEach(results) { track in
                TrackRowView(track: track,
                             isLiked: playerVM.isLiked(track),
                             onToggleLike: { playerVM.toggleLike(track) })
                    .onTapGesture { tap(track) }
                    .swipeActions(edge: .trailing) {
                        Button { playerVM.addToQueue(track) } label: {
                            Label("Queue", systemImage: "plus")
                        }
                        .tint(primary)
                        Button { playerVM.toggleLike(track) } label: {
                            Label(playerVM.isLiked(track) ? "Unlike" : "Like",
                                  systemImage: playerVM.isLiked(track) ? "heart.slash" : "heart")
                        }
                        .tint(.pink)
                    }
                    .listRowBackground(bg)
                    .listRowSeparatorTint(Color.white.opacity(0.06))
                    .onAppear {
                        if track.id == results.last?.id { loadMore() }
                    }
            }
            if isLoadingMore {
                HStack { Spacer(); ProgressView().tint(primary); Spacer() }
                    .listRowBackground(bg)
                    .listRowSeparatorTint(.clear)
            }
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
            let tracks = try await SoundCloudService.shared.search(query: q, offset: 0)
            guard !Task.isCancelled else { return }
            currentQuery = q
            results = tracks
        } catch {
            searchError = error.localizedDescription
        }
    }

    private func loadMore() {
        guard !isLoadingMore, !isSearching, !currentQuery.isEmpty else { return }
        isLoadingMore = true
        Task {
            do {
                let more = try await SoundCloudService.shared.search(query: currentQuery, offset: results.count)
                let newTracks = more.filter { t in !results.contains(where: { $0.id == t.id }) }
                results.append(contentsOf: newTracks)
            } catch {}
            isLoadingMore = false
        }
    }
}
