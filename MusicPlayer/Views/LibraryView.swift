import SwiftUI
import UIKit

// MARK: - Sort options

enum FavoritesSort: String, CaseIterable {
    case `default`   = "Default"
    case titleAZ     = "By title"
    case artistAZ    = "By artist"
    case durationAsc = "By duration"
    case titleZA     = "By title (Z-A)"
    case artistZA    = "By artist (Z-A)"
    case durationDesc = "By duration ↓"
    case random      = "Random"
    case newestFirst = "Newest first"
    case oldestFirst = "Oldest first"

    var icon: String {
        switch self {
        case .default:     return "line.3.horizontal"
        case .titleAZ:     return "textformat"
        case .artistAZ:    return "person"
        case .durationAsc: return "timer"
        case .titleZA:     return "arrow.up.and.down.text.horizontal"
        case .artistZA:    return "arrow.up.and.down.text.horizontal"
        case .durationDesc: return "arrow.up.and.down.text.horizontal"
        case .random:      return "shuffle"
        case .newestFirst: return "arrow.counterclockwise"
        case .oldestFirst: return "clock"
        }
    }
}

// MARK: - Library root

struct LibraryView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showLiked        = false
    @State private var showCreateSheet  = false
    @State private var newPlaylistName  = ""
    @State private var selectedPlaylist: LocalPlaylist?

    private var bg:      Color { themeManager.current.background }
    private var bgCard:  Color { themeManager.current.card }
    private var primary: Color { themeManager.current.primary }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    likedTracksCard
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    if playerVM.likedTracks.isEmpty {
                        voidDetected.padding(.horizontal, 16)
                    }

                    playlistsSection.padding(.horizontal, 16)
                }
                .padding(.bottom, 120)
            }
            .background(bg.ignoresSafeArea())
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showLiked) {
            LikedTracksView().environmentObject(playerVM).environmentObject(themeManager)
        }
        .sheet(item: $selectedPlaylist) { pl in
            PlaylistDetailView(playlist: pl).environmentObject(playerVM).environmentObject(themeManager)
        }
        .alert("New Playlist", isPresented: $showCreateSheet) {
            TextField("Name", text: $newPlaylistName)
            Button("Create") {
                let name = newPlaylistName.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { playerVM.createPlaylist(name: name) }
                newPlaylistName = ""
            }
            Button("Cancel", role: .cancel) { newPlaylistName = "" }
        }
    }

    // MARK: - Favorites card

    private var likedTracksCard: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [primary, primary.opacity(0.55)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Circle().fill(Color.white.opacity(0.08)).frame(width: 130)
                .offset(x: 80, y: -16)
            Circle().fill(Color.white.opacity(0.06)).frame(width: 90)
                .offset(x: 230, y: 12)

            Image(systemName: "heart.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 3) {
                Text("Favorites")
                    .font(.custom("Courier New", size: 18)).bold()
                    .foregroundStyle(.white)
                Text("\(playerVM.likedTracks.count) tracks")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .padding(16)
        }
        .frame(height: 110)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .contextMenu {
            Button {
                guard !playerVM.likedTracks.isEmpty else { return }
                playerVM.playFromList(playerVM.likedTracks, startingWith: playerVM.likedTracks[0])
            } label: { Label("Play", systemImage: "play.fill") }

            Button {
                guard !playerVM.likedTracks.isEmpty else { return }
                let s = playerVM.likedTracks.shuffled()
                playerVM.playFromList(s, startingWith: s[0])
            } label: { Label("Shuffle", systemImage: "shuffle") }
        } preview: {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [primary, primary.opacity(0.55)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                Circle().fill(Color.white.opacity(0.08)).frame(width: 130).offset(x: 80, y: -16)
                Circle().fill(Color.white.opacity(0.06)).frame(width: 90).offset(x: 230, y: 12)
                Image(systemName: "heart.fill")
                    .font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                    .padding(16).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Favorites").font(.custom("Courier New", size: 18)).bold().foregroundStyle(.white)
                    Text("\(playerVM.likedTracks.count) tracks").font(.system(size: 12)).foregroundStyle(.white.opacity(0.75))
                }.padding(16)
            }
            .frame(width: 300, height: 110)
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .onTapGesture { if !playerVM.likedTracks.isEmpty { showLiked = true } }
    }

    // MARK: - Empty state

    private var voidDetected: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.03))
                .strokeBorder(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 1, dash: [6]))
                .frame(height: 160)
            VStack(spacing: 10) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.06)).frame(width: 56, height: 56)
                    Image(systemName: "heart").font(.system(size: 22)).foregroundStyle(.white.opacity(0.25))
                }
                Text("VOID DETECTED")
                    .font(.system(size: 13, weight: .black)).kerning(2).foregroundStyle(.white.opacity(0.5))
                Text("YOUR COLLECTION IS CURRENTLY EMPTY.\nINITIALIZE BY LIKING TRACKS.")
                    .font(.system(size: 9, weight: .bold)).kerning(1)
                    .foregroundStyle(.white.opacity(0.25)).multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Playlists section

    private var playlistsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("PLAYLISTS")
                    .font(.system(size: 14, weight: .black)).foregroundStyle(.white)
                Spacer()
                Button { showCreateSheet = true } label: {
                    Text("CREATE NEW +")
                        .font(.system(size: 10, weight: .black)).kerning(1).foregroundStyle(primary)
                }
            }

            if playerVM.playlists.isEmpty {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.04))
                    .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
                    .frame(height: 80)
                    .overlay(
                        Text("NO PLAYLISTS YET")
                            .font(.system(size: 10, weight: .black)).kerning(2)
                            .foregroundStyle(.white.opacity(0.2))
                    )
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 14) {
                    ForEach(playerVM.playlists) { pl in
                        PlaylistCard(playlist: pl)
                            .onTapGesture { selectedPlaylist = pl }
                            .contextMenu {
                                Button(role: .destructive) { playerVM.deletePlaylist(pl.id) } label: {
                                    Label("Delete Playlist", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
    }
}

// MARK: - Playlist card

private struct PlaylistCard: View {
    let playlist: LocalPlaylist
    @EnvironmentObject var themeManager: ThemeManager
    private var bg: Color { themeManager.current.card }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            artworkView
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            Text(playlist.name.uppercased())
                .font(.system(size: 11, weight: .black)).kerning(1)
                .foregroundStyle(.white).lineLimit(1)
            Text("\(playlist.tracks.count) TRACKS")
                .font(.system(size: 9, weight: .bold)).kerning(1)
                .foregroundStyle(themeManager.current.primary.opacity(0.7))
        }
    }

    @ViewBuilder
    private var artworkView: some View {
        let urls = playlist.mosaicURLs
        if urls.count >= 4 {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 0), GridItem(.flexible(), spacing: 0)], spacing: 0) {
                ForEach(urls.prefix(4), id: \.self) { u in
                    AsyncImage(url: URL(string: u)) { img in
                        img.resizable().aspectRatio(1, contentMode: .fill)
                    } placeholder: { bg }
                }
            }
        } else if let first = urls.first {
            AsyncImage(url: URL(string: first)) { img in img.resizable().aspectRatio(contentMode: .fill) }
                placeholder: { bg }
        } else {
            ZStack {
                bg
                Image(systemName: "music.note.list").font(.system(size: 32)).foregroundStyle(.white.opacity(0.2))
            }
        }
    }
}

// MARK: - Liked tracks view

struct LikedTracksView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    @State private var showSort    = false
    @State private var showSearch  = false
    @State private var searchText  = ""
    @State private var sortOrder: FavoritesSort = .default
    @State private var randomized: [Track]?

    private var bg:      Color { themeManager.current.background }
    private var primary: Color { themeManager.current.primary }

    private var displayedTracks: [Track] {
        let base = playerVM.likedTracks
        let filtered = searchText.isEmpty ? base : base.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.username.localizedCaseInsensitiveContains(searchText)
        }
        switch sortOrder {
        case .default:     return filtered
        case .titleAZ:     return filtered.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
        case .artistAZ:    return filtered.sorted { $0.username.localizedCompare($1.username) == .orderedAscending }
        case .durationAsc: return filtered.sorted { ($0.duration ?? 0) < ($1.duration ?? 0) }
        case .titleZA:     return filtered.sorted { $0.title.localizedCompare($1.title) == .orderedDescending }
        case .artistZA:    return filtered.sorted { $0.username.localizedCompare($1.username) == .orderedDescending }
        case .durationDesc: return filtered.sorted { ($0.duration ?? 0) > ($1.duration ?? 0) }
        case .random:      return randomized ?? filtered
        case .newestFirst: return filtered
        case .oldestFirst: return filtered.reversed()
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Hero header
                Section {
                    heroHeader
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                // Search bar
                if showSearch {
                    Section {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.white.opacity(0.4))
                            TextField("Search", text: $searchText)
                                .foregroundStyle(.white)
                                .tint(primary)
                            if !searchText.isEmpty {
                                Button { searchText = "" } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.4))
                                }
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16).padding(.vertical, 6)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(bg)
                        .listRowSeparator(.hidden)
                    }
                }

                // Play / shuffle row
                Section {
                    HStack(spacing: 12) {
                        Button {
                            guard !displayedTracks.isEmpty else { return }
                            playerVM.playFromList(displayedTracks, startingWith: displayedTracks[0])
                            playerVM.showingNowPlaying = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill").font(.system(size: 14, weight: .bold))
                                Text("Play").font(.system(size: 16, weight: .bold))
                            }
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(.white, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)

                        Button {
                            guard !displayedTracks.isEmpty else { return }
                            let s = displayedTracks.shuffled()
                            playerVM.playFromList(s, startingWith: s[0])
                            playerVM.showingNowPlaying = true
                        } label: {
                            Image(systemName: "shuffle")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(primary)
                                .frame(width: 50, height: 50)
                                .background(primary.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(bg)
                    .listRowSeparator(.hidden)
                }

                // Track list
                Section {
                    ForEach(displayedTracks) { track in
                        LikedTrackRow(track: track)
                            .onTapGesture {
                                playerVM.playFromList(displayedTracks, startingWith: track)
                                playerVM.showingNowPlaying = true
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    playerVM.toggleLike(track)
                                } label: { Label("Unlike", systemImage: "heart.slash") }
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(bg)
                            .listRowSeparatorTint(Color.white.opacity(0.06))
                    }
                }
            }
            .listStyle(.plain)
            .background(bg.ignoresSafeArea())
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 6) {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                                .padding(8).background(Color.white.opacity(0.15), in: Circle())
                        }
                        Button { showSort = true } label: {
                            Image(systemName: "line.3.horizontal.decrease")
                                .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                                .padding(8).background(Color.white.opacity(0.15), in: Circle())
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 6) {
                        Button { withAnimation(.spring(response: 0.3)) { showSearch.toggle() }; if !showSearch { searchText = "" } } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                                .padding(8).background(Color.white.opacity(0.15), in: Circle())
                        }
                        Menu {
                            Button {
                                guard !displayedTracks.isEmpty else { return }
                                playerVM.playFromList(displayedTracks, startingWith: displayedTracks[0])
                                playerVM.showingNowPlaying = true
                            } label: { Label("Play All", systemImage: "play.fill") }

                            Button {
                                guard !displayedTracks.isEmpty else { return }
                                let s = displayedTracks.shuffled()
                                playerVM.playFromList(s, startingWith: s[0])
                                playerVM.showingNowPlaying = true
                            } label: { Label("Shuffle", systemImage: "shuffle") }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                                .padding(8).background(Color.white.opacity(0.15), in: Circle())
                        }
                    }
                }
            }
            .toolbarBackground(primary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .presentationBackground(bg)
        .sheet(isPresented: $showSort) {
            FavoritesSortSheet(sortOrder: $sortOrder)
                .environmentObject(themeManager)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color(red: 0.07, green: 0.07, blue: 0.07))
                .presentationCornerRadius(24)
        }
        .onChange(of: sortOrder) { _, new in
            if new == .random { randomized = playerVM.likedTracks.shuffled() }
            else { randomized = nil }
        }
    }

    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [primary, primary.opacity(0.6)],
                startPoint: .top, endPoint: .bottom
            )
            Circle().fill(Color.white.opacity(0.08)).frame(width: 200).offset(x: -50, y: 40)
            Circle().fill(Color.white.opacity(0.06)).frame(width: 140).offset(x: 230, y: 10)

            VStack(alignment: .leading, spacing: 5) {
                Text("Favorites")
                    .font(.custom("Courier New", size: 34)).bold()
                    .foregroundStyle(.white)
                Text("\(playerVM.likedTracks.count) tracks")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.horizontal, 20).padding(.bottom, 24)
        }
        .frame(height: 220)
    }
}

// MARK: - Liked track row

private struct LikedTrackRow: View {
    let track: Track
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var dm = DownloadManager.shared
    @State private var showDownload = false

    private var primary: Color { themeManager.current.primary }
    private var isPlaying: Bool { playerVM.currentTrack?.id == track.id }

    var body: some View {
        HStack(spacing: 12) {
            ArtworkThumbnail(url: track.thumbnailArtworkURL)

            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white).lineLimit(1)
                Text(track.username)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5)).lineLimit(1)
            }

            Spacer()

            Button { showDownload = true } label: {
                downloadIndicator
            }
            .buttonStyle(.plain)

            Text(track.durationFormatted)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
                .monospacedDigit()
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .contentShape(Rectangle())
        .sheet(isPresented: $showDownload) {
            DownloadOptionsSheet(track: track)
                .environmentObject(themeManager)
                .presentationDetents([.fraction(0.55)])
                .presentationBackground(themeManager.current.background)
                .presentationCornerRadius(28)
        }
    }

    @ViewBuilder
    private var downloadIndicator: some View {
        let cached  = dm.cachedIDs.contains(track.id)
        let offline = dm.offlineIDs.contains(track.id)
        let icon    = isPlaying && playerVM.isPlaying ? "chart.bar.fill"
                    : offline  ? "checkmark.circle.fill"
                    : cached   ? "cylinder.split.1x2"
                    : "arrow.down.to.line"
        let color: Color = isPlaying && playerVM.isPlaying ? primary
                         : offline ? primary.opacity(0.8)
                         : cached  ? .white.opacity(0.55)
                         : .white.opacity(0.3)
        Image(systemName: icon)
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(color)
            .frame(width: 32, height: 32)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Sort sheet

struct FavoritesSortSheet: View {
    @Binding var sortOrder: FavoritesSort
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(FavoritesSort.allCases, id: \.self) { sort in
                    Button {
                        sortOrder = sort
                        dismiss()
                    } label: {
                        HStack(spacing: 18) {
                            Image(systemName: sort.icon)
                                .font(.system(size: 17, weight: .regular))
                                .foregroundStyle(.white)
                                .frame(width: 26, alignment: .center)
                            Text(sort.rawValue)
                                .font(.custom("Courier New", size: 17)).bold()
                                .foregroundStyle(.white)
                            Spacer()
                            if sortOrder == sort {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(.horizontal, 24).padding(.vertical, 18)
                    }
                    .buttonStyle(.plain)

                    if sort != FavoritesSort.allCases.last {
                        Divider().background(Color.white.opacity(0.07))
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Playlist detail view

struct PlaylistDetailView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    let playlist: LocalPlaylist

    private var currentPlaylist: LocalPlaylist {
        playerVM.playlists.first(where: { $0.id == playlist.id }) ?? playlist
    }

    private var bg:     Color { themeManager.current.background }
    private var bgCard: Color { themeManager.current.card }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    artworkHeader
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal, 50)
                        .padding(.top, 16).padding(.bottom, 12)

                    Text(currentPlaylist.name.uppercased())
                        .font(.system(size: 22, weight: .black)).foregroundStyle(.white)
                    Text("\(currentPlaylist.tracks.count) TRACKS")
                        .font(.system(size: 10, weight: .bold)).kerning(1.5)
                        .foregroundStyle(themeManager.current.primary.opacity(0.7)).padding(.top, 4)

                    HStack(spacing: 16) {
                        Button {
                            guard !currentPlaylist.tracks.isEmpty else { return }
                            playerVM.playFromList(currentPlaylist.tracks, startingWith: currentPlaylist.tracks[0])
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
                            guard !currentPlaylist.tracks.isEmpty else { return }
                            let s = currentPlaylist.tracks.shuffled()
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

                    if currentPlaylist.tracks.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "music.note").font(.system(size: 36)).foregroundStyle(themeManager.current.primary.opacity(0.3))
                            Text("NO TRACKS YET")
                                .font(.system(size: 13, weight: .black)).kerning(2).foregroundStyle(.white.opacity(0.4))
                            Text("Add tracks from the Search tab.")
                                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.25))
                        }
                        .padding(.top, 60)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(currentPlaylist.tracks) { track in
                                TrackRowView(track: track,
                                             isLiked: playerVM.isLiked(track),
                                             onToggleLike: { playerVM.toggleLike(track) })
                                    .onTapGesture {
                                        playerVM.playFromList(currentPlaylist.tracks, startingWith: track)
                                        playerVM.showingNowPlaying = true
                                        dismiss()
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            playerVM.removeTrackFromPlaylist(track.id, playlistID: playlist.id)
                                        } label: { Label("Remove", systemImage: "minus.circle") }
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold)).foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
        .presentationBackground(bg)
    }

    @ViewBuilder
    private var artworkHeader: some View {
        let urls = currentPlaylist.mosaicURLs
        if urls.count >= 4 {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 0), GridItem(.flexible(), spacing: 0)], spacing: 0) {
                ForEach(urls.prefix(4), id: \.self) { u in
                    AsyncImage(url: URL(string: u)) { img in img.resizable().aspectRatio(1, contentMode: .fill) }
                        placeholder: { bgCard }
                }
            }
        } else if let first = urls.first {
            AsyncImage(url: URL(string: first)) { img in img.resizable().aspectRatio(contentMode: .fill) }
                placeholder: { bgCard }
        } else {
            ZStack { bgCard; Image(systemName: "music.note.list").font(.system(size: 56)).foregroundStyle(.white.opacity(0.15)) }
        }
    }
}

// MARK: - Download options sheet

struct DownloadOptionsSheet: View {
    let track: Track
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    @StateObject private var dm = DownloadManager.shared

    @State private var preparingExport = false
    @State private var exportURL: URL?
    @State private var showDocPicker  = false
    @State private var toast: String?
    @State private var toastTask: Task<Void, Never>?

    private var bg:     Color { themeManager.current.background }
    private var bgCard: Color { themeManager.current.card }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.white.opacity(0.25))
                .frame(width: 36, height: 4)
                .padding(.top, 12).padding(.bottom, 18)

            Text("DOWNLOAD")
                .font(.system(size: 10, weight: .black)).kerning(2)
                .foregroundStyle(.white.opacity(0.35))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20).padding(.bottom, 12)

            VStack(spacing: 10) {
                optionRow(
                    icon: "cylinder.split.1x2",
                    title: "Save to cache",
                    subtitle: "Audio in storage",
                    badge: "\(dm.cachedIDs.count) / ∞",
                    done: dm.cachedIDs.contains(track.id),
                    busy: dm.downloading.contains(track.id)
                ) {
                    Task {
                        guard let url = await resolveStream() else { return }
                        await dm.saveToCache(track: track, streamURL: url)
                        showToast("Saved to cache")
                    }
                }

                optionRow(
                    icon: "internaldrive",
                    title: "Download offline",
                    subtitle: "MP3 file on device",
                    badge: "\(dm.offlineIDs.count) / ∞",
                    done: dm.offlineIDs.contains(track.id),
                    busy: dm.downloading.contains(track.id)
                ) {
                    Task {
                        guard let url = await resolveStream() else { return }
                        await dm.downloadOffline(track: track, streamURL: url)
                        showToast("Saved offline")
                    }
                }

                optionRow(
                    icon: "folder",
                    title: "Save to folder...",
                    subtitle: "Choose folder on device",
                    badge: nil,
                    done: false,
                    busy: preparingExport
                ) {
                    Task {
                        preparingExport = true
                        guard let streamURL = await resolveStream() else { preparingExport = false; return }
                        exportURL = await dm.prepareExport(track: track, streamURL: streamURL)
                        preparingExport = false
                        if exportURL != nil { showDocPicker = true }
                    }
                }
            }
            .padding(.horizontal, 20)

            Button { dismiss() } label: {
                Text("Back")
                    .font(.system(size: 15, weight: .black)).kerning(1)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 18)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20).padding(.top, 16)

            Spacer()
        }
        .preferredColorScheme(.dark)
        .overlay(alignment: .bottom) {
            if let msg = toast {
                Text(msg)
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: toast)
        .sheet(isPresented: $showDocPicker) {
            if let url = exportURL {
                DocumentExportPicker(fileURL: url) { showDocPicker = false }
            }
        }
    }

    @ViewBuilder
    private func optionRow(icon: String, title: String, subtitle: String,
                           badge: String?, done: Bool, busy: Bool,
                           action: @escaping () -> Void) -> some View {
        Button(action: { if !done && !busy { action() } }) {
            HStack(spacing: 16) {
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 12).fill(bgCard).frame(width: 58, height: 58)
                    VStack(spacing: 3) {
                        Image(systemName: icon)
                            .font(.system(size: 22, weight: .regular)).foregroundStyle(.white)
                        if let b = badge {
                            Text(b)
                                .font(.system(size: 7, weight: .black))
                                .foregroundStyle(.white.opacity(0.5))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.white.opacity(0.1), in: Capsule())
                        }
                    }
                    .padding(.bottom, 6)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(.white.opacity(0.4))
                }
                Spacer()
                if busy {
                    ProgressView().tint(.white).scaleEffect(0.85)
                } else if done {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18)).foregroundStyle(themeManager.current.primary)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.25))
                }
            }
            .padding(14)
            .background(bgCard, in: RoundedRectangle(cornerRadius: 16))
            .opacity(done ? 0.6 : 1)
        }
        .buttonStyle(.plain)
    }

    private func resolveStream() async -> URL? {
        guard let transcoding = track.media?.progressiveTranscoding else { return nil }
        return try? await SoundCloudService.shared.resolveStreamURL(transcodingURL: transcoding.url)
    }

    private func showToast(_ msg: String) {
        toastTask?.cancel()
        toast = msg
        toastTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            toast = nil
        }
    }
}

// MARK: - Document export picker

struct DocumentExportPicker: UIViewControllerRepresentable {
    let fileURL: URL
    let onDismiss: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onDismiss: onDismiss) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let vc = UIDocumentPickerViewController(forExporting: [fileURL], asCopy: true)
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onDismiss: () -> Void
        init(onDismiss: @escaping () -> Void) { self.onDismiss = onDismiss }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) { onDismiss() }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { onDismiss() }
    }
}
