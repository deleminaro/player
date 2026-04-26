import SwiftUI

struct HomeView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showArchive = false

    private var bg:     Color { themeManager.current.background }
    private var bgCard: Color { themeManager.current.card }
    private var accent: Color { themeManager.current.primary }

    private var featured: Track? { playerVM.recentlyPlayed.first }
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    heroCard
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    quickAccessRow
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    if !playerVM.recentlyPlayed.isEmpty {
                        recentSection
                            .padding(.top, 28)
                    } else {
                        emptyHero
                            .padding(.top, 48)
                    }
                }
                .padding(.bottom, 120)
            }
            .background(bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Postor")
                        .font(themeManager.font(20, .bold))
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Circle()
                        .fill(accent)
                        .frame(width: 8, height: 8)
                }
            }
        }
        .sheet(isPresented: $showArchive) {
            RecentlyPlayedView()
                .environmentObject(playerVM)
        }
    }

    // MARK: - Quick access row

    private var quickAccessRow: some View {
        HStack(spacing: 12) {
            QuickAccessCard(
                title: "Recent",
                trackCount: playerVM.recentlyPlayed.count,
                artworks: playerVM.recentlyPlayed.prefix(2).compactMap { $0.thumbnailArtworkURL },
                bgCard: bgCard,
                accent: accent,
                themeManager: themeManager
            )
            .onTapGesture {
                guard !playerVM.recentlyPlayed.isEmpty else { return }
                playerVM.playFromList(playerVM.recentlyPlayed, startingWith: playerVM.recentlyPlayed[0])
                playerVM.showingNowPlaying = true
            }

            QuickAccessCard(
                title: "Favorites",
                trackCount: playerVM.likedTracks.count,
                artworks: playerVM.likedTracks.prefix(2).compactMap { $0.thumbnailArtworkURL },
                bgCard: bgCard,
                accent: accent,
                themeManager: themeManager
            )
            .onTapGesture {
                guard !playerVM.likedTracks.isEmpty else { return }
                playerVM.playFromList(playerVM.likedTracks, startingWith: playerVM.likedTracks[0])
                playerVM.showingNowPlaying = true
            }
        }
    }

    // MARK: - Hero card

    private var heroCard: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let url = URL(string: featured?.highResArtworkURL ?? "") {
                    AsyncImage(url: url) { img in
                        img.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: { bgCard }
                } else {
                    bgCard
                }
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.75)],
                startPoint: .top, endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 8) {
                if let t = featured {
                    Text(t.title)
                        .font(themeManager.font(20, .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(t.username)
                        .font(themeManager.font(13))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                } else {
                    Text("Your music,\neverywhere.")
                        .font(themeManager.font(22, .bold))
                        .foregroundStyle(.white)
                }

                HStack(spacing: 10) {
                    Button {
                        if let t = playerVM.recentlyPlayed.first {
                            playerVM.play(t)
                            playerVM.showingNowPlaying = true
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text("Play")
                                .font(themeManager.font(14, .semibold))
                        }
                        .foregroundStyle(themeManager.current.onPrimary)
                        .padding(.horizontal, 22).padding(.vertical, 11)
                        .background(accent, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle(scale: 0.93))
                    .sensoryFeedback(.impact(.medium), trigger: playerVM.currentTrack?.id)
                    .opacity(featured == nil ? 0.35 : 1)
                    .disabled(featured == nil)

                    Button { showArchive = true } label: {
                        Text("Archive")
                            .font(themeManager.font(14))
                            .foregroundStyle(.white.opacity(0.65))
                            .padding(.horizontal, 22).padding(.vertical, 11)
                            .background(Color.white.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle(scale: 0.93))
                }
            }
            .padding(18)
        }
        .frame(height: 210)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Recently played grid

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Recently played")
                    .font(themeManager.font(16, .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Button { showArchive = true } label: {
                    Text("See all")
                        .font(themeManager.font(13))
                        .foregroundStyle(accent)
                }
            }
            .padding(.horizontal, 16)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(playerVM.recentlyPlayed.prefix(6)) { track in
                    RecentTrackCard(track: track)
                        .onTapGesture {
                            playerVM.play(track)
                            playerVM.showingNowPlaying = true
                        }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Empty state

    private var emptyHero: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.system(size: 36))
                .foregroundStyle(accent.opacity(0.4))
            Text("Nothing yet")
                .font(themeManager.font(16, .semibold))
                .foregroundStyle(.white.opacity(0.5))
            Text("Search for tracks to get started.")
                .font(themeManager.font(13))
                .foregroundStyle(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}

// MARK: - Quick access card

private struct QuickAccessCard: View {
    let title: String
    let trackCount: Int
    let artworks: [String]
    let bgCard: Color
    let accent: Color
    let themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomLeading) {
                ArtworkThumbnail(url: artworks.count > 1 ? artworks[1] : artworks.first)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .offset(x: 10, y: -7)
                    .opacity(artworks.count > 1 ? 1 : 0)

                ArtworkThumbnail(url: artworks.first)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
            }
            .frame(width: 52, height: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(themeManager.font(13, .semibold))
                    .foregroundStyle(.white)
                Text("\(trackCount) tracks")
                    .font(themeManager.font(11))
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            // Explicit play affordance
            ZStack {
                Circle()
                    .fill(accent.opacity(0.18))
                    .frame(width: 34, height: 34)
                Image(systemName: "play.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(accent)
                    .offset(x: 1)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 13)
        .background(bgCard, in: RoundedRectangle(cornerRadius: 14))
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Recent track card

struct RecentTrackCard: View {
    let track: Track
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: URL(string: track.highResArtworkURL ?? "")) { img in
                    img.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.white.opacity(0.07)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 22))
                                .foregroundStyle(.white.opacity(0.12))
                        )
                }
                .aspectRatio(1, contentMode: .fill)

                // Play badge — shows this is tappable
                ZStack {
                    Circle()
                        .fill(.black.opacity(0.52))
                        .frame(width: 30, height: 30)
                    Image(systemName: "play.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .offset(x: 1)
                }
                .padding(7)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(themeManager.font(12, .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(track.username)
                    .font(themeManager.font(11))
                    .foregroundStyle(themeManager.current.primary.opacity(0.75))
                    .lineLimit(1)
            }
        }
    }
}
