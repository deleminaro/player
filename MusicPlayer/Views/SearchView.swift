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

private enum SearchResultSet {
    case tracks([Track])
    case playlists([SCPlaylist])
    case artists([SCArtist])
    case empty
}

struct SearchView: View {
    @EnvironmentObject var playerVM: PlayerViewModel

    @State private var query              = ""
    @State private var resultSet          = SearchResultSet.empty
    @State private var isSearching        = false
    @State private var isLoadingMore      = false
    @State private var addToPlaylistTrack: Track?
    @State private var searchError:  String?
    @State private var searchTask:   Task<Void, Never>?
    @State private var filter        = SearchFilter.all
    @State private var currentQuery  = ""
    @FocusState private var focused: Bool

    private let bg      = Color(red: 0.075, green: 0.075, blue: 0.075)
    private let bgField = Color(red: 0.14,  green: 0.14,  blue: 0.14)
    private let primary = Color(red: 0.753, green: 0.757, blue: 1.0)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 12).padding(.bottom, 14)

                filterChips
                    .padding(.bottom, 12)

                Divider().background(Color.white.opacity(0.06))

                contentArea
            }
            .background(bg.ignoresSafeArea())
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(bg, for: .navigationBar)
            .preferredColorScheme(.dark)
        }
        .sheet(item: $addToPlaylistTrack) { track in
            AddToPlaylistSheet(track: track).environmentObject(playerVM)
        }
        .onTapGesture { focused = false }
        .onChange(of: filter) { _, _ in
            guard !currentQuery.isEmpty else { return }
            Task { await performSearch(currentQuery, reset: true) }
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
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
                Button { query = ""; resultSet = .empty; searchError = nil } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.4))
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .background(bgField, in: Capsule())
    }

    // MARK: - Filter chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(SearchFilter.allCases, id: \.self) { f in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) { filter = f }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: f.icon)
                                .font(.system(size: 12, weight: .semibold))
                            Text(f.rawValue)
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundStyle(filter == f ? .black : .white)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Capsule().fill(filter == f ? .white : bgField))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Content area

    @ViewBuilder
    private var contentArea: some View {
        if isSearching {
            ProgressView().tint(primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let err = searchError {
            errorState(err)
        } else {
            switch resultSet {
            case .tracks(let tracks):
                trackList(tracks)
            case .playlists(let lists):
                playlistList(lists)
            case .artists(let artists):
                artistList(artists)
            case .empty:
                recentSearchesView
            }
        }
    }

    // MARK: - Track list

    private func trackList(_ tracks: [Track]) -> some View {
        List {
            ForEach(tracks) { track in
                TrackRowView(track: track,
                             isLiked: playerVM.isLiked(track),
                             onToggleLike: { playerVM.toggleLike(track) })
                    .onTapGesture { tap(track) }
                    .swipeActions(edge: .trailing) {
                        Button { playerVM.addToQueue(track) } label: {
                            Label("Queue", systemImage: "plus")
                        }.tint(primary)
                        Button { playerVM.toggleLike(track) } label: {
                            Label(playerVM.isLiked(track) ? "Unlike" : "Like",
                                  systemImage: playerVM.isLiked(track) ? "heart.slash" : "heart")
                        }.tint(.pink)
                        Button { addToPlaylistTrack = track } label: {
                            Label("Playlist", systemImage: "music.note.list")
                        }.tint(.indigo)
                    }
                    .listRowBackground(bg)
                    .listRowSeparatorTint(Color.white.opacity(0.06))
                    .onAppear { if track.id == tracks.last?.id { loadMore() } }
            }
            if isLoadingMore {
                HStack { Spacer(); ProgressView().tint(primary); Spacer() }
                    .listRowBackground(bg).listRowSeparatorTint(.clear)
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Playlist list

    private func playlistList(_ playlists: [SCPlaylist]) -> some View {
        List {
            ForEach(playlists) { pl in
                PlaylistRowView(playlist: pl)
                    .onTapGesture { tapPlaylist(pl) }
                    .listRowBackground(bg)
                    .listRowSeparatorTint(Color.white.opacity(0.06))
                    .onAppear { if pl.id == playlists.last?.id { loadMore() } }
            }
            if isLoadingMore {
                HStack { Spacer(); ProgressView().tint(primary); Spacer() }
                    .listRowBackground(bg).listRowSeparatorTint(.clear)
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Artist list

    private func artistList(_ artists: [SCArtist]) -> some View {
        List {
            ForEach(artists) { artist in
                ArtistRowView(artist: artist)
                    .onTapGesture { tapArtist(artist) }
                    .listRowBackground(bg)
                    .listRowSeparatorTint(Color.white.opacity(0.06))
                    .onAppear { if artist.id == artists.last?.id { loadMore() } }
            }
            if isLoadingMore {
                HStack { Spacer(); ProgressView().tint(primary); Spacer() }
                    .listRowBackground(bg).listRowSeparatorTint(.clear)
            }
        }
        .listStyle(.plain)
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
                                Button { query = s; commitSearch() } label: {
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
                            .font(.system(size: 44)).foregroundStyle(primary.opacity(0.25))
                        Text("SEARCH MUSIC")
                            .font(.system(size: 13, weight: .black)).kerning(2)
                            .foregroundStyle(.white.opacity(0.4))
                        Text("Songs, artists, playlists and more.")
                            .font(.system(size: 12)).foregroundStyle(.white.opacity(0.25))
                    }
                    .frame(maxWidth: .infinity).padding(.top, 60)
                }
            }
            .padding(.top, 20).padding(.bottom, 120)
        }
    }

    // MARK: - Error / empty states

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
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(40)
    }

    // MARK: - Actions

    private func tap(_ track: Track) {
        playerVM.addToQueue(track)
        playerVM.play(track)
        playerVM.showingNowPlaying = true
    }

    private func tapPlaylist(_ pl: SCPlaylist) {
        Task {
            guard let tracks = try? await SoundCloudService.shared.fetchPlaylistTracks(id: pl.id),
                  !tracks.isEmpty else { return }
            playerVM.playFromList(tracks, startingWith: tracks[0])
            playerVM.showingNowPlaying = true
        }
    }

    private func tapArtist(_ artist: SCArtist) {
        query = artist.username
        filter = .tracks
        commitSearch()
    }

    // MARK: - Search logic

    private func commitSearch() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        playerVM.addRecentSearch(q)
        Task { await performSearch(q, reset: true) }
    }

    private func scheduleSearch(_ q: String) {
        searchTask?.cancel()
        searchError = nil
        guard !q.trimmingCharacters(in: .whitespaces).isEmpty else {
            resultSet = .empty; return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            await performSearch(q, reset: true)
        }
    }

    private func performSearch(_ q: String, reset: Bool) async {
        isSearching = true
        defer { isSearching = false }
        do {
            let offset = reset ? 0 : currentResultCount
            currentQuery = q
            switch filter {
            case .all, .tracks:
                let tracks = try await SoundCloudService.shared.search(query: q, offset: offset)
                if reset { resultSet = .tracks(tracks) }
                else if case .tracks(var existing) = resultSet {
                    existing.append(contentsOf: tracks.filter { t in !existing.contains { $0.id == t.id } })
                    resultSet = .tracks(existing)
                }
            case .playlists:
                let lists = try await SoundCloudService.shared.searchPlaylists(query: q, offset: offset)
                if reset { resultSet = .playlists(lists) }
                else if case .playlists(var existing) = resultSet {
                    existing.append(contentsOf: lists.filter { l in !existing.contains { $0.id == l.id } })
                    resultSet = .playlists(existing)
                }
            case .albums:
                let lists = try await SoundCloudService.shared.searchAlbums(query: q, offset: offset)
                if reset { resultSet = .playlists(lists) }
                else if case .playlists(var existing) = resultSet {
                    existing.append(contentsOf: lists.filter { l in !existing.contains { $0.id == l.id } })
                    resultSet = .playlists(existing)
                }
            case .artists:
                let users = try await SoundCloudService.shared.searchArtists(query: q, offset: offset)
                if reset { resultSet = .artists(users) }
                else if case .artists(var existing) = resultSet {
                    existing.append(contentsOf: users.filter { u in !existing.contains { $0.id == u.id } })
                    resultSet = .artists(existing)
                }
            }
        } catch {
            searchError = error.localizedDescription
        }
    }

    private var currentResultCount: Int {
        switch resultSet {
        case .tracks(let t):    return t.count
        case .playlists(let p): return p.count
        case .artists(let a):   return a.count
        case .empty:            return 0
        }
    }

    private func loadMore() {
        guard !isLoadingMore, !isSearching, !currentQuery.isEmpty else { return }
        isLoadingMore = true
        Task {
            await performSearch(currentQuery, reset: false)
            isLoadingMore = false
        }
    }
}

// MARK: - Playlist row

private struct PlaylistRowView: View {
    let playlist: SCPlaylist
    private let primary = Color(red: 0.753, green: 0.757, blue: 1.0)

    var body: some View {
        HStack(spacing: 14) {
            ArtworkThumbnail(url: playlist.thumbnailArtworkURL)

            VStack(alignment: .leading, spacing: 3) {
                Text(playlist.title.uppercased())
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(playlist.username.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(primary)
                    .kerning(1.5)
                    .lineLimit(1)
            }

            Spacer()

            Text("\(playlist.trackCount) TRACKS")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(0.3))
                .kerning(1)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
    }
}

// MARK: - Artist row

private struct ArtistRowView: View {
    let artist: SCArtist
    private let primary = Color(red: 0.753, green: 0.757, blue: 1.0)

    var body: some View {
        HStack(spacing: 14) {
            ArtworkThumbnail(url: artist.avatarURL)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(artist.username.uppercased())
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if !artist.formattedFollowers.isEmpty {
                    Text(artist.formattedFollowers.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.35))
                        .kerning(1.5)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.2))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
    }
}

// MARK: - Add to playlist sheet

struct AddToPlaylistSheet: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @Environment(\.dismiss) var dismiss
    let track: Track

    @State private var showCreate = false
    @State private var newName    = ""

    private let bg      = Color(red: 0.075, green: 0.075, blue: 0.075)
    private let primary = Color(red: 0.753, green: 0.757, blue: 1.0)

    var body: some View {
        NavigationStack {
            List {
                Button { showCreate = true } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(primary.opacity(0.15)).frame(width: 48, height: 48)
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .bold)).foregroundStyle(primary)
                        }
                        Text("NEW PLAYLIST")
                            .font(.system(size: 12, weight: .black)).kerning(1).foregroundStyle(primary)
                    }
                    .padding(.vertical, 6)
                }
                .listRowBackground(bg)

                ForEach(playerVM.playlists) { pl in
                    Button {
                        playerVM.addTrackToPlaylist(track, playlistID: pl.id)
                        dismiss()
                    } label: {
                        HStack(spacing: 14) {
                            ArtworkThumbnail(url: pl.thumbnailArtworkURL)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(pl.name.uppercased())
                                    .font(.system(size: 12, weight: .black))
                                    .foregroundStyle(.white).lineLimit(1)
                                Text("\(pl.tracks.count) TRACKS")
                                    .font(.system(size: 9, weight: .bold)).kerning(1)
                                    .foregroundStyle(.white.opacity(0.35))
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .listRowBackground(bg)
                }
            }
            .listStyle(.plain)
            .background(bg.ignoresSafeArea())
            .navigationTitle("ADD TO PLAYLIST")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold)).foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(bg)
        .alert("New Playlist", isPresented: $showCreate) {
            TextField("Name", text: $newName)
            Button("Create & Add") {
                let name = newName.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty {
                    let pl = playerVM.createPlaylist(name: name)
                    playerVM.addTrackToPlaylist(track, playlistID: pl.id)
                }
                newName = ""; dismiss()
            }
            Button("Cancel", role: .cancel) { newName = "" }
        }
    }
}
