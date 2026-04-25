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
    @EnvironmentObject var themeManager: ThemeManager

    @State private var query              = ""
    @State private var resultSet          = SearchResultSet.empty
    @State private var isSearching        = false
    @State private var isLoadingMore      = false
    @State private var addToPlaylistTrack: Track?
    @State private var selectedPlaylist:  SCPlaylist?
    @State private var searchError:  String?
    @State private var searchTask:   Task<Void, Never>?
    @State private var filter        = SearchFilter.all
    @State private var currentQuery  = ""
    @State private var source        = TrackSource.soundcloud
    @State private var showSpotifyLogin = false
    @State private var spotifyAuthError: String?
    @FocusState private var focused: Bool

    @ObservedObject private var spotify = SpotifyService.shared

    private var bg:      Color { themeManager.current.background }
    private var bgField: Color { themeManager.current.card }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 12).padding(.bottom, 14)

                if source == .soundcloud {
                    filterChips
                        .padding(.bottom, 12)
                }

                Divider().background(Color.white.opacity(0.06))

                if source == .spotify && !spotify.isAuthenticated {
                    spotifyConnectPrompt
                } else {
                    contentArea
                }
            }
            .background(bg.ignoresSafeArea())
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    sourceToggleButton
                }
            }
        }
        .sheet(item: $addToPlaylistTrack) { track in
            AddToPlaylistSheet(track: track).environmentObject(playerVM).environmentObject(themeManager)
        }
        .sheet(item: $selectedPlaylist) { pl in
            SCPlaylistDetailView(playlist: pl).environmentObject(playerVM).environmentObject(themeManager)
        }
        .onTapGesture { focused = false }
        .onChange(of: filter) { _, _ in
            guard !currentQuery.isEmpty, source == .soundcloud else { return }
            Task { await performSearch(currentQuery, reset: true) }
        }
        .onChange(of: source) { _, _ in
            resultSet = .empty
            searchError = nil
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

    // MARK: - Source toggle button (nav bar)

    private var sourceToggleButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                source = source == .soundcloud ? .spotify : .soundcloud
                resultSet = .empty
                searchError = nil
                if !currentQuery.isEmpty {
                    Task { await performSearch(currentQuery, reset: true) }
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(source == .spotify
                          ? Color(red: 0.11, green: 0.73, blue: 0.33)
                          : Color(red: 1.0, green: 0.34, blue: 0.0))
                    .frame(width: 36, height: 36)

                if source == .spotify {
                    Text("S")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(.black)
                } else {
                    Image(systemName: "waveform")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Spotify connect prompt

    private var spotifyConnectPrompt: some View {
        VStack(spacing: 20) {
            Spacer()
            Circle()
                .fill(Color(red: 0.11, green: 0.73, blue: 0.33).opacity(0.15))
                .frame(width: 80, height: 80)
                .overlay(
                    Text("S")
                        .font(.system(size: 40, weight: .black))
                        .foregroundStyle(Color(red: 0.11, green: 0.73, blue: 0.33))
                )

            Text("CONNECT SPOTIFY")
                .font(.system(size: 14, weight: .black)).kerning(2)
                .foregroundStyle(.white)

            Text("Sign in to search Spotify's catalog\nand play 30s previews.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)

            if let err = spotifyAuthError {
                Text(err)
                    .font(.system(size: 11))
                    .foregroundStyle(.red.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                Task {
                    spotifyAuthError = nil
                    do {
                        try await SpotifyService.shared.startAuth()
                        if !currentQuery.isEmpty {
                            await performSearch(currentQuery, reset: true)
                        }
                    } catch SpotifyError.authCancelled {
                        // user cancelled — no error shown
                    } catch {
                        spotifyAuthError = error.localizedDescription
                    }
                }
            } label: {
                Text("CONNECT")
                    .font(.system(size: 14, weight: .black)).kerning(1.5)
                    .foregroundStyle(.black)
                    .frame(width: 180)
                    .padding(.vertical, 14)
                    .background(Color(red: 0.11, green: 0.73, blue: 0.33), in: Capsule())
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
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
            ProgressView().tint(themeManager.current.primary)
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
                    .onTapGesture { tap(track, in: tracks) }
                    .swipeActions(edge: .trailing) {
                        Button { playerVM.addToQueue(track) } label: {
                            Label("Queue", systemImage: "plus")
                        }.tint(themeManager.current.primary)
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
                HStack { Spacer(); ProgressView().tint(themeManager.current.primary); Spacer() }
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
                HStack { Spacer(); ProgressView().tint(themeManager.current.primary); Spacer() }
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
                HStack { Spacer(); ProgressView().tint(themeManager.current.primary); Spacer() }
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
                                .foregroundStyle(themeManager.current.primary)
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
                            .font(.system(size: 44)).foregroundStyle(themeManager.current.primary.opacity(0.25))
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

    private func tap(_ track: Track, in tracks: [Track]) {
        playerVM.playFromList(tracks, startingWith: track)
        playerVM.showingNowPlaying = true
    }

    private func tapPlaylist(_ pl: SCPlaylist) {
        selectedPlaylist = pl
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

            if source == .spotify {
                let tracks = try await SpotifyService.shared.search(query: q, offset: offset)
                if reset { resultSet = .tracks(tracks) }
                else if case .tracks(var existing) = resultSet {
                    existing.append(contentsOf: tracks.filter { t in !existing.contains { $0.id == t.id } })
                    resultSet = .tracks(existing)
                }
                return
            }

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
    @EnvironmentObject var themeManager: ThemeManager

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
                    .foregroundStyle(themeManager.current.primary)
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
    @EnvironmentObject var themeManager: ThemeManager

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

// MARK: - SoundCloud Playlist / Album detail sheet

struct SCPlaylistDetailView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    let playlist: SCPlaylist

    @State private var tracks:    [Track] = []
    @State private var isLoading: Bool    = true
    @State private var failed:    Bool    = false
    @State private var toast:     String? = nil

    private var bg:      Color { themeManager.current.background }
    private var bgCard:  Color { themeManager.current.card }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    AsyncImage(url: URL(string: playlist.artworkURL?
                        .replacingOccurrences(of: "-large.", with: "-t500x500.")
                        .replacingOccurrences(of: "-t300x300.", with: "-t500x500.") ?? "")) { img in
                        img.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: { bgCard }
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.top, 24).padding(.bottom, 16)

                    Text(playlist.title.uppercased())
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Text(playlist.username.uppercased())
                        .font(.system(size: 10, weight: .bold)).kerning(1.5)
                        .foregroundStyle(themeManager.current.primary.opacity(0.7))
                        .padding(.top, 4)
                    Text("\(playlist.trackCount) TRACKS")
                        .font(.system(size: 9, weight: .bold)).kerning(1)
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.top, 2)

                    if isLoading {
                        ProgressView().tint(themeManager.current.primary).padding(.top, 40)
                    } else if failed {
                        VStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 32)).foregroundStyle(.orange.opacity(0.5))
                            Text("COULDN'T LOAD TRACKS")
                                .font(.system(size: 12, weight: .black)).kerning(2)
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .padding(.top, 40)
                    } else {
                        HStack(spacing: 16) {
                            Button {
                                guard !tracks.isEmpty else { return }
                                playerVM.playFromList(tracks, startingWith: tracks[0])
                                playerVM.showingNowPlaying = true
                                dismiss()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "play.fill")
                                    Text("PLAY").font(.system(size: 13, weight: .black)).kerning(1)
                                }
                                .foregroundStyle(themeManager.current.onPrimary)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(themeManager.current.primary, in: RoundedRectangle(cornerRadius: 14))
                            }
                            Button {
                                guard !tracks.isEmpty else { return }
                                let s = tracks.shuffled()
                                playerVM.playFromList(s, startingWith: s[0])
                                playerVM.showingNowPlaying = true
                                dismiss()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "shuffle")
                                    Text("SHUFFLE").font(.system(size: 13, weight: .black)).kerning(1)
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                            }
                        }
                        .padding(.horizontal, 20).padding(.top, 20)

                        LazyVStack(spacing: 0) {
                            ForEach(tracks) { track in
                                TrackRowView(track: track,
                                             isLiked: playerVM.isLiked(track),
                                             onToggleLike: { playerVM.toggleLike(track) })
                                    .onTapGesture {
                                        playerVM.playFromList(tracks, startingWith: track)
                                        playerVM.showingNowPlaying = true
                                        dismiss()
                                    }
                                Divider().background(Color.white.opacity(0.06)).padding(.leading, 76)
                            }
                        }
                        .padding(.top, 16)
                    }
                }
                .padding(.bottom, 100)
            }
            .background(bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !tracks.isEmpty {
                        Menu {
                            Button {
                                addToLibrary()
                            } label: {
                                Label("Add to Library", systemImage: "square.and.arrow.down")
                            }
                            Button {
                                likeAllTracks()
                            } label: {
                                Label("Add Songs to Favourites", systemImage: "heart")
                            }
                        } label: {
                            ZStack {
                                Circle().fill(Color.white.opacity(0.12)).frame(width: 36, height: 36)
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold)).foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .preferredColorScheme(.dark)
            .overlay(alignment: .top) {
                if let msg = toast {
                    Text(msg)
                        .font(.system(size: 12, weight: .bold)).kerning(0.5)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: toast)
        }
        .presentationBackground(bg)
        .task {
            do {
                tracks = try await SoundCloudService.shared.fetchPlaylistTracks(id: playlist.id)
                isLoading = false
            } catch {
                isLoading = false
                failed = true
            }
        }
    }

    private func addToLibrary() {
        guard !tracks.isEmpty else { return }
        let pl = playerVM.createPlaylist(name: playlist.title)
        for track in tracks {
            playerVM.addTrackToPlaylist(track, playlistID: pl.id)
        }
        showToast("Added to Library")
    }

    private func likeAllTracks() {
        guard !tracks.isEmpty else { return }
        var added = 0
        for track in tracks where !playerVM.isLiked(track) {
            playerVM.toggleLike(track)
            added += 1
        }
        showToast(added > 0 ? "\(added) Songs Added to Favourites" : "Already in Favourites")
    }

    private func showToast(_ msg: String) {
        toast = msg
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            toast = nil
        }
    }
}

// MARK: - Add to playlist sheet

