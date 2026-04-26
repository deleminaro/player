import SwiftUI

struct SpotifyArtistProfileView: View {
    @EnvironmentObject var playerVM:     PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    let artist: SpotifyArtistResult

    @State private var topTracks:  [Track]              = []
    @State private var albums:     [SpotifyAlbumResult] = []
    @State private var isLoading:  Bool                 = true
    @State private var loadError:  String?              = nil
    @State private var activeTab:  SpotifyArtistTab     = .topTracks
    @State private var showAlbumAlert: Bool             = false
    @State private var tappedAlbum: SpotifyAlbumResult?

    private enum SpotifyArtistTab { case topTracks, albums }

    private let spotifyGreen = Color(red: 0.11, green: 0.73, blue: 0.33)

    private var bg:   Color { themeManager.current.background }
    private var card: Color { themeManager.current.card }
    private var accent: Color { themeManager.current.primary }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                    genrePills
                        .padding(.top, 14)
                    tabBar
                        .padding(.top, 16)
                        .padding(.bottom, 6)
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
        .alert("Album", isPresented: $showAlbumAlert, presenting: tappedAlbum) { _ in
            Button("OK", role: .cancel) {}
        } message: { album in
            Text("\(album.name) — coming soon.")
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            // Background image or green gradient fallback
            if let urlStr = artist.imageURL, let url = URL(string: urlStr) {
                GeometryReader { geo in
                    AsyncImage(url: url) { img in
                        img.resizable()
                           .aspectRatio(contentMode: .fill)
                           .frame(width: geo.size.width, height: 220)
                           .clipped()
                    } placeholder: {
                        spotifyHeroGradient.frame(width: geo.size.width, height: 220)
                    }
                    .frame(width: geo.size.width, height: 220)
                }
                .frame(height: 220)
            } else {
                spotifyHeroGradient.frame(maxWidth: .infinity).frame(height: 220)
                    .overlay(
                        Text("S")
                            .font(.system(size: 80, weight: .black))
                            .foregroundStyle(.black.opacity(0.25))
                    )
            }

            // Bottom gradient fade
            LinearGradient(
                colors: [.clear, bg.opacity(0.85), bg],
                startPoint: .init(x: 0.5, y: 0.25),
                endPoint: .bottom
            )
            .frame(height: 220)

            // Name + listeners
            VStack(alignment: .leading, spacing: 4) {
                Text(artist.name)
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 4, y: 2)

                if let count = artist.followersCount {
                    Text("\(formattedListeners(count)) MONTHLY LISTENERS")
                        .font(.system(size: 10, weight: .semibold))
                        .kerning(1)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    private var spotifyHeroGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.02, green: 0.48, blue: 0.22),
                Color(red: 0.06, green: 0.30, blue: 0.14)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Genre pills

    @ViewBuilder
    private var genrePills: some View {
        let displayGenres = Array(artist.genres.prefix(3))
        if !displayGenres.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(displayGenres, id: \.self) { genre in
                        Text(genre.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .kerning(1)
                            .foregroundStyle(spotifyGreen)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .strokeBorder(spotifyGreen.opacity(0.4), lineWidth: 1)
                                    .background(Capsule().fill(spotifyGreen.opacity(0.08)))
                            )
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton("TOP TRACKS", tab: .topTracks)
            tabButton("ALBUMS", tab: .albums)
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private func tabButton(_ label: String, tab: SpotifyArtistTab) -> some View {
        let isActive = activeTab == tab
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) { activeTab = tab }
        } label: {
            VStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 11, weight: .black))
                    .kerning(1.5)
                    .foregroundStyle(isActive ? .white : .white.opacity(0.35))
                Rectangle()
                    .fill(isActive ? spotifyGreen : .clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
        .frame(minWidth: 90)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentSection: some View {
        if isLoading {
            ProgressView()
                .tint(spotifyGreen)
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        } else if let err = loadError {
            errorView(err)
        } else if activeTab == .topTracks {
            topTracksContent
        } else {
            albumsGrid
        }
    }

    private var topTracksContent: some View {
        LazyVStack(spacing: 0) {
            if topTracks.isEmpty {
                emptyLabel("NO TRACKS AVAILABLE")
            } else {
                ForEach(Array(topTracks.enumerated()), id: \.element.id) { index, track in
                    HStack(spacing: 0) {
                        Text("\(index + 1)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.25))
                            .frame(width: 30)
                        TrackRowView(
                            track: track,
                            isLiked: playerVM.isLiked(track),
                            onToggleLike: { playerVM.toggleLike(track) }
                        )
                    }
                    .onTapGesture {
                        playerVM.play(track)
                        playerVM.showingNowPlaying = true
                    }
                    Divider()
                        .background(Color.white.opacity(0.05))
                        .padding(.leading, 106)
                }
            }
        }
        .padding(.top, 8)
    }

    private var albumsGrid: some View {
        LazyVStack(spacing: 0) {
            if albums.isEmpty {
                emptyLabel("NO ALBUMS FOUND")
            } else {
                let rows = stride(from: 0, to: albums.count, by: 2).map { i -> [SpotifyAlbumResult] in
                    var row: [SpotifyAlbumResult] = [albums[i]]
                    if i + 1 < albums.count { row.append(albums[i + 1]) }
                    return row
                }
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 12) {
                        ForEach(row) { album in
                            albumCell(album)
                        }
                        if row.count == 1 { Spacer() }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
        }
        .padding(.top, 12)
    }

    private func albumCell(_ album: SpotifyAlbumResult) -> some View {
        Button {
            tappedAlbum = album
            showAlbumAlert = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(card)
                    if let urlStr = album.imageURL, let url = URL(string: urlStr) {
                        AsyncImage(url: url) { img in
                            img.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            card
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 24))
                            .foregroundStyle(.white.opacity(0.2))
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(album.name)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 4) {
                        Text(album.releaseYear)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.35))
                        Text("·")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.2))
                        Text(album.albumType.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .kerning(0.5)
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
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
            async let t = SpotifyService.shared.fetchArtistTopTracks(artistID: artist.id)
            async let a = SpotifyService.shared.fetchArtistAlbums(artistID: artist.id)
            topTracks = try await t
            albums    = try await a
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Helpers

    private func formattedListeners(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000     { return String(format: "%.0fK", Double(n) / 1_000) }
        return "\(n)"
    }
}
