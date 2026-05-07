import SwiftUI

struct SpotifyAlbumDetailView: View {
    @EnvironmentObject var playerVM:     PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    let album: SpotifyAlbumResult

    @State private var tracks:    [Track] = []
    @State private var isLoading: Bool    = true

    private let spotifyGreen = Color(red: 0.11, green: 0.73, blue: 0.33)
    private var bg:   Color { themeManager.current.background }
    private var card: Color { themeManager.current.card }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    header
                    if isLoading {
                        ProgressView()
                            .tint(spotifyGreen)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else if tracks.isEmpty {
                        Text("NO TRACKS AVAILABLE")
                            .font(.app(11, .bold)).kerning(1.5)
                            .foregroundStyle(.white.opacity(0.25))
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else {
                        trackList
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
                            .font(.app(13, .bold))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
        .presentationBackground(bg)
        .task { await loadTracks() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 14) {
            if let urlStr = album.imageURL, let url = URL(string: urlStr) {
                AsyncImage(url: url) { img in
                    img.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12).fill(card)
                }
                .frame(width: 180, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.5), radius: 20, y: 8)
                .padding(.top, 24)
            }

            VStack(spacing: 4) {
                Text(album.name)
                    .font(.app(20, .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                if let artist = album.artistName {
                    Text(artist)
                        .font(.app(13))
                        .foregroundStyle(spotifyGreen)
                }
                Text("\(album.releaseYear) · \(album.albumType.uppercased())")
                    .font(.app(11, .semibold)).kerning(0.5)
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(.horizontal, 24)

            // Play all button
            if !tracks.isEmpty {
                Button {
                    playerVM.playFromList(tracks, startingWith: tracks[0])
                    playerVM.showingNowPlaying = true
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.app(14, .bold))
                        Text("Play All")
                            .font(.app(15, .bold))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 32).padding(.vertical, 12)
                    .background(spotifyGreen, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle(scale: 0.93))
            }
        }
        .padding(.bottom, 20)
    }

    // MARK: - Track list

    private var trackList: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(tracks.enumerated()), id: \.offset) { index, track in
                HStack(spacing: 0) {
                    Text("\(index + 1)")
                        .font(.app(11, .bold))
                        .foregroundStyle(.white.opacity(0.25))
                        .frame(width: 30)
                    TrackRowView(
                        track: track,
                        isLiked: playerVM.isLiked(track),
                        onToggleLike: { playerVM.toggleLike(track) }
                    )
                }
                .onTapGesture {
                    playerVM.playFromList(tracks, startingWith: track)
                    playerVM.showingNowPlaying = true
                    dismiss()
                }
                Divider()
                    .background(Color.white.opacity(0.05))
                    .padding(.leading, 106)
            }
        }
        .padding(.top, 8)
    }

    private func loadTracks() async {
        isLoading = true
        tracks    = (try? await SpotifyService.shared.fetchAlbumTracks(album: album)) ?? []
        isLoading = false
    }
}
