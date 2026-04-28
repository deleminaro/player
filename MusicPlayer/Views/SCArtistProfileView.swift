import SwiftUI

struct SCArtistProfileView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    let artist: SCArtist

    @State private var tracks:    [Track]      = []
    @State private var playlists: [SCPlaylist] = []
    @State private var isLoading: Bool         = true
    @State private var loadError: String?      = nil
    @State private var activeTab: ArtistTab    = .tracks
    @State private var selectedPlaylist: SCPlaylist? = nil
    @State private var playlistTracks: [Track]       = []
    @State private var loadingPlaylist               = false

    private enum ArtistTab { case tracks, playlists }

    private var bg:   Color { themeManager.current.background }
    private var card: Color { themeManager.current.card }
    private var accent: Color { themeManager.current.primary }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                    tabPills
                        .padding(.top, 20)
                        .padding(.bottom, 8)
                    contentSection
                }
                .padding(.bottom, 100)
            }
            .background(bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
        .presentationBackground(bg)
        .task { await loadData() }
        .sheet(item: $selectedPlaylist) { pl in
            SCPlaylistTracksView(
                playlist: pl,
                tracks: playlistTracks
            )
            .environmentObject(playerVM)
            .environmentObject(themeManager)
            .presentationBackground(bg)
            .presentationDetents([.large])
            .presentationCornerRadius(28)
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            // Blurred full-bleed background
            GeometryReader { geo in
                AsyncImage(url: URL(string: artist.avatarURL ?? "")) { img in
                    img.resizable()
                       .aspectRatio(contentMode: .fill)
                       .frame(width: geo.size.width, height: 220)
                       .blur(radius: 28)
                       .brightness(-0.22)
                       .clipped()
                } placeholder: {
                    card
                }
                .frame(width: geo.size.width, height: 220)
            }
            .frame(height: 220)

            // Gradient overlay at bottom of hero
            LinearGradient(
                colors: [.clear, bg],
                startPoint: .init(x: 0.5, y: 0.3),
                endPoint: .bottom
            )
            .frame(height: 220)

            // Centered avatar + text
            VStack(spacing: 10) {
                ArtworkThumbnail(url: artist.avatarURL)
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.15), lineWidth: 1.5))
                    .shadow(color: .black.opacity(0.5), radius: 12, y: 6)

                Text(artist.username)
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                if let followers = artist.followersCount {
                    Text(formattedFollowers(followers).uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .kerning(1.5)
                        .foregroundStyle(accent)
                }
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - Tab pills

    private var tabPills: some View {
        HStack(spacing: 8) {
            tabPill("TRACKS", tab: .tracks, count: tracks.count)
            tabPill("PLAYLISTS", tab: .playlists, count: playlists.count)
        }
        .padding(.horizontal, 20)
    }

    private func tabPill(_ label: String, tab: ArtistTab, count: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { activeTab = tab }
        } label: {
            HStack(spacing: 5) {
                Text(label)
                    .font(.system(size: 11, weight: .black))
                    .kerning(1.5)
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(activeTab == tab ? bg.opacity(0.4) : card)
                        .clipShape(Capsule())
                }
            }
            .foregroundStyle(activeTab == tab ? themeManager.current.onPrimary : .white.opacity(0.5))
            .padding(.horizontal, 18).padding(.vertical, 10)
            .background(
                Capsule().fill(activeTab == tab ? accent : card)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentSection: some View {
        if isLoading {
            ProgressView()
                .tint(accent)
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        } else if let err = loadError {
            errorView(err)
        } else if activeTab == .tracks {
            tracksContent
        } else {
            playlistsContent
        }
    }

    private var tracksContent: some View {
        LazyVStack(spacing: 0) {
            if tracks.isEmpty {
                emptyLabel("NO TRACKS FOUND")
            } else {
                ForEach(tracks) { track in
                    TrackRowView(
                        track: track,
                        isLiked: playerVM.isLiked(track),
                        onToggleLike: { playerVM.toggleLike(track) }
                    )
                    .onTapGesture {
                        playerVM.playFromList(tracks, startingWith: track)
                        playerVM.showingNowPlaying = true
                        dismiss()
                    }
                    Divider()
                        .background(Color.white.opacity(0.06))
                        .padding(.leading, 76)
                }
            }
        }
        .padding(.top, 8)
    }

    private var playlistsContent: some View {
        LazyVStack(spacing: 0) {
            if playlists.isEmpty {
                emptyLabel("NO PLAYLISTS FOUND")
            } else {
                ForEach(playlists) { pl in
                    playlistRow(pl)
                    Divider()
                        .background(Color.white.opacity(0.06))
                        .padding(.leading, 76)
                }
            }
        }
        .padding(.top, 8)
    }

    private func playlistRow(_ pl: SCPlaylist) -> some View {
        HStack(spacing: 14) {
            ArtworkThumbnail(url: pl.thumbnailArtworkURL)

            VStack(alignment: .leading, spacing: 3) {
                Text(pl.title.uppercased())
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("\(pl.trackCount) TRACKS")
                    .font(.system(size: 9, weight: .bold))
                    .kerning(1)
                    .foregroundStyle(.white.opacity(0.3))
            }

            Spacer()

            if loadingPlaylist && selectedPlaylist?.id == pl.id {
                ProgressView().tint(.white)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.2))
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
        .onTapGesture { openPlaylist(pl) }
    }

    private func openPlaylist(_ pl: SCPlaylist) {
        guard !loadingPlaylist else { return }
        selectedPlaylist = pl
        loadingPlaylist = true
        Task {
            do {
                let fetched = try await SoundCloudService.shared.fetchPlaylistTracks(id: pl.id)
                playlistTracks = fetched
                loadingPlaylist = false
            } catch {
                loadingPlaylist = false
            }
        }
    }

    private func emptyLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold)).kerning(1.5)
            .foregroundStyle(.white.opacity(0.25))
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(.orange.opacity(0.6))
            Text("COULDN'T LOAD PROFILE")
                .font(.system(size: 13, weight: .black)).kerning(2)
                .foregroundStyle(.white.opacity(0.4))
            Text(msg)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.25))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .padding(.horizontal, 32)
    }

    // MARK: - Data loading

    private func loadData() async {
        isLoading = true
        loadError = nil
        do {
            async let t = SoundCloudService.shared.fetchUserTracks(userID: artist.id)
            async let p = SoundCloudService.shared.fetchUserPlaylists(userID: artist.id)
            tracks    = try await t
            playlists = try await p
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Helpers

    private func formattedFollowers(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM followers", Double(n) / 1_000_000) }
        if n >= 1_000     { return String(format: "%.0fK followers", Double(n) / 1_000) }
        return "\(n) followers"
    }
}

// MARK: - Playlist tracks sheet

struct SCPlaylistTracksView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    let playlist: SCPlaylist
    let tracks: [Track]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    if tracks.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 36))
                                .foregroundStyle(.white.opacity(0.2))
                            Text("NO TRACKS")
                                .font(.system(size: 11, weight: .bold)).kerning(1.5)
                                .foregroundStyle(.white.opacity(0.25))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        ForEach(tracks) { track in
                            TrackRowView(
                                track: track,
                                isLiked: playerVM.isLiked(track),
                                onToggleLike: { playerVM.toggleLike(track) }
                            )
                            .onTapGesture {
                                playerVM.playFromList(tracks, startingWith: track)
                                playerVM.showingNowPlaying = true
                                dismiss()
                            }
                            Divider()
                                .background(Color.white.opacity(0.06))
                                .padding(.leading, 76)
                        }
                    }
                }
                .padding(.bottom, 100)
            }
            .background(themeManager.current.background.ignoresSafeArea())
            .navigationTitle(playlist.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                if !tracks.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            playerVM.playFromList(tracks, startingWith: tracks[0])
                            playerVM.showingNowPlaying = true
                            dismiss()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "play.fill")
                                Text("Play All")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(themeManager.current.primary)
                        }
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}
