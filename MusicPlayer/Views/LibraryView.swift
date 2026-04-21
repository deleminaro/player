import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showLiked        = false
    @State private var showCreateSheet  = false
    @State private var newPlaylistName  = ""
    @State private var selectedPlaylist: LocalPlaylist?

    private let bg       = Color(red: 0.075, green: 0.075, blue: 0.075)
    private let bgCard   = Color(red: 0.110, green: 0.110, blue: 0.110)

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

    // MARK: - Liked tracks card

    private var likedTracksCard: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if playerVM.likedTracks.count >= 4 {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 0), GridItem(.flexible(), spacing: 0)], spacing: 0) {
                        ForEach(playerVM.likedTracks.prefix(4)) { t in
                            AsyncImage(url: URL(string: t.highResArtworkURL ?? "")) { img in
                                img.resizable().aspectRatio(1, contentMode: .fill)
                            } placeholder: { bgCard }
                        }
                    }
                } else if let url = URL(string: playerVM.likedTracks.first?.highResArtworkURL ?? "") {
                    AsyncImage(url: url) { img in
                        img.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: { bgCard }
                } else {
                    bgCard
                }
            }

            LinearGradient(colors: [.black.opacity(0.05), .black.opacity(0.72)],
                           startPoint: .top, endPoint: .bottom)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("LIKED\nTRACKS")
                        .font(.system(size: 28, weight: .black)).foregroundStyle(.white)
                    Text(String(playerVM.likedTracks.count) + " CURATED MASTERPIECES")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(themeManager.current.primary.opacity(0.8)).kerning(1.5)
                }
                Spacer()
                Button {
                    guard !playerVM.likedTracks.isEmpty else { return }
                    let s = playerVM.likedTracks.shuffled()
                    playerVM.playFromList(s, startingWith: s[0])
                    playerVM.showingNowPlaying = true
                } label: {
                    ZStack {
                        Circle().fill(themeManager.current.primary).frame(width: 44, height: 44)
                        Image(systemName: "shuffle").font(.system(size: 16, weight: .bold)).foregroundStyle(themeManager.current.onPrimary)
                    }
                }
                .opacity(playerVM.likedTracks.isEmpty ? 0.4 : 1)
                .disabled(playerVM.likedTracks.isEmpty)
            }
            .padding(20)
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .onTapGesture { if !playerVM.likedTracks.isEmpty { showLiked = true } }
    }

    // MARK: - Void empty state

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
                    .font(.system(size: 18, weight: .black)).foregroundStyle(.white)
                Spacer()
                Button { showCreateSheet = true } label: {
                    Text("CREATE NEW +")
                        .font(.system(size: 10, weight: .black)).kerning(1).foregroundStyle(themeManager.current.primary)
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
    private let bg    = Color(red: 0.110, green: 0.110, blue: 0.110)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            artworkView
                .frame(height: 140)
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
            AsyncImage(url: URL(string: first)) { img in
                img.resizable().aspectRatio(contentMode: .fill)
            } placeholder: { bg }
        } else {
            ZStack {
                bg
                Image(systemName: "music.note.list").font(.system(size: 32)).foregroundStyle(.white.opacity(0.2))
            }
        }
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

    private let bg      = Color(red: 0.075, green: 0.075, blue: 0.075)
    private let bgCard  = Color(red: 0.110, green: 0.110, blue: 0.110)

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header artwork
                    artworkHeader
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal, 40)
                        .padding(.top, 20)
                        .padding(.bottom, 16)

                    // Title + track count
                    Text(currentPlaylist.name.uppercased())
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(.white)
                    Text("\(currentPlaylist.tracks.count) TRACKS")
                        .font(.system(size: 10, weight: .bold)).kerning(1.5)
                        .foregroundStyle(themeManager.current.primary.opacity(0.7))
                        .padding(.top, 4)

                    // Play / Shuffle buttons
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

                    // Track list
                    if currentPlaylist.tracks.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "music.note").font(.system(size: 36)).foregroundStyle(themeManager.current.primary.opacity(0.3))
                            Text("NO TRACKS YET")
                                .font(.system(size: 13, weight: .black)).kerning(2)
                                .foregroundStyle(.white.opacity(0.4))
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
                                        } label: {
                                            Label("Remove", systemImage: "minus.circle")
                                        }
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
                    AsyncImage(url: URL(string: u)) { img in
                        img.resizable().aspectRatio(1, contentMode: .fill)
                    } placeholder: { bgCard }
                }
            }
        } else if let first = urls.first {
            AsyncImage(url: URL(string: first)) { img in img.resizable().aspectRatio(contentMode: .fill) }
                placeholder: { bgCard }
        } else {
            ZStack {
                bgCard
                Image(systemName: "music.note.list").font(.system(size: 56)).foregroundStyle(.white.opacity(0.15))
            }
        }
    }
}

// MARK: - Liked tracks full list

struct LikedTracksView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    private let bg      = Color(red: 0.075, green: 0.075, blue: 0.075)

    var body: some View {
        NavigationStack {
            List(playerVM.likedTracks) { track in
                TrackRowView(track: track,
                             isLiked: playerVM.isLiked(track),
                             onToggleLike: { playerVM.toggleLike(track) })
                    .onTapGesture {
                        playerVM.playFromList(playerVM.likedTracks, startingWith: track)
                        playerVM.showingNowPlaying = true
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { playerVM.toggleLike(track) } label: {
                            Label("Unlike", systemImage: "heart.slash")
                        }
                    }
                    .listRowBackground(bg)
                    .listRowSeparatorTint(Color.white.opacity(0.06))
            }
            .listStyle(.plain)
            .background(bg.ignoresSafeArea())
            .navigationTitle("LIKED TRACKS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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
}
