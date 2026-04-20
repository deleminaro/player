import SwiftUI

struct SearchView: View {
    @EnvironmentObject var playerVM: PlayerViewModel

    @State private var query       = ""
    @State private var results:    [Track] = []
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var searchTask: Task<Void, Never>?
    @State private var source      = SearchSource.all

    private let bg      = Color(red: 0.075, green: 0.075, blue: 0.075)
    private let bgCard  = Color(red: 0.110, green: 0.110, blue: 0.110)
    private let primary = Color(red: 0.753, green: 0.757, blue: 1.0)
    private let onPrimary = Color(red: 0.063, green: 0, blue: 0.663)

    enum SearchSource: String, CaseIterable {
        case all = "ALL", soundcloud = "SOUNDCLOUD", youtube = "YOUTUBE"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.35))
                        TextField("", text: $query,
                                  prompt: Text("Search for tracks, artists...")
                                    .foregroundStyle(.white.opacity(0.3))
                                    .font(.system(size: 13)))
                            .foregroundStyle(.white)
                            .font(.system(size: 13))
                            .autocorrectionDisabled()
                            .onSubmit { commitSearch() }
                            .onChange(of: query) { _, new in scheduleSearch(new) }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 13)
                    .background(Color.white.opacity(0.07), in: Capsule())

                    Button { commitSearch() } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(primary.opacity(0.18))
                                .frame(width: 42, height: 42)
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(primary)
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 14)

                // Source filter
                HStack(spacing: 8) {
                    Text("SOURCE:")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(.white.opacity(0.3))
                        .kerning(1.5)
                    ForEach(SearchSource.allCases, id: \.self) { s in
                        Button { source = s } label: {
                            Text(s.rawValue)
                                .font(.system(size: 10, weight: .black)).kerning(0.5)
                                .foregroundStyle(source == s ? onPrimary : .white.opacity(0.55))
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(
                                    source == s ? primary : Color.white.opacity(0.07),
                                    in: Capsule()
                                )
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.bottom, 14)

                Divider().background(Color.white.opacity(0.06))

                // Content
                Group {
                    if isSearching {
                        Spacer()
                        ProgressView()
                            .tint(primary)
                            .scaleEffect(1.1)
                        Spacer()
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 6) {
                        Text("P")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(primary)
                            .padding(6)
                            .background(primary.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                        Text("POSTOR.")
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(.white)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 4) {
                        Circle().fill(.green).frame(width: 7, height: 7)
                        Text("LIVE")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(.white)
                            .kerning(1)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.white.opacity(0.08), in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
            }
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
                            Text("CLEAR HISTORY")
                                .font(.system(size: 9, weight: .black)).kerning(1)
                                .foregroundStyle(primary)
                        }
                    }
                    .padding(.horizontal, 16)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(playerVM.recentSearches, id: \.self) { s in
                                Button {
                                    query = s
                                    commitSearch()
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
                                    .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 36))
                            .foregroundStyle(primary.opacity(0.3))
                        Text("SEARCH MUSIC")
                            .font(.system(size: 13, weight: .black)).kerning(2)
                            .foregroundStyle(.white.opacity(0.4))
                        Text("Search for songs, artists, or playlists.")
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
                    Button {
                        playerVM.addToQueue(track)
                    } label: {
                        Label("Queue", systemImage: "plus")
                    }
                    .tint(Color(red: 0.753, green: 0.757, blue: 1.0))

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
