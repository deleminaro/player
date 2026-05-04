import SwiftUI
import UIKit

// MARK: - Sort options

enum FavoritesSort: String, CaseIterable {
    case `default`    = "Default"
    case titleAZ      = "By title"
    case artistAZ     = "By artist"
    case durationAsc  = "By duration"
    case titleZA      = "By title (Z-A)"
    case artistZA     = "By artist (Z-A)"
    case durationDesc = "By duration ↓"
    case random       = "Random"
    case newestFirst  = "Newest first"
    case oldestFirst  = "Oldest first"

    var icon: String {
        switch self {
        case .default:      return "line.3.horizontal"
        case .titleAZ:      return "textformat"
        case .artistAZ:     return "person"
        case .durationAsc:  return "timer"
        case .titleZA:      return "arrow.up.and.down.text.horizontal"
        case .artistZA:     return "arrow.up.and.down.text.horizontal"
        case .durationDesc: return "arrow.up.and.down.text.horizontal"
        case .random:       return "shuffle"
        case .newestFirst:  return "arrow.counterclockwise"
        case .oldestFirst:  return "clock"
        }
    }
}

// MARK: - Library root

struct LibraryView: View {
    @EnvironmentObject var playerVM:    PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showLiked        = false
    @State private var showCreateSheet  = false
    @State private var newPlaylistName  = ""
    @State private var selectedPlaylist: LocalPlaylist?

    private var bg:     Color { themeManager.current.background }
    private var card:   Color { themeManager.current.card }
    private var accent: Color { themeManager.current.primary }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    statsRow
                        .padding(.horizontal, 20)
                        .padding(.top, 4)

                    likedSection

                    playlistSection
                }
                .padding(.bottom, 120)
            }
            .background(bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("LIBRARY")
                        .font(.system(size: 12, weight: .black))
                        .kerning(2.5)
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showCreateSheet = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(accent)
                    }
                }
            }
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

    // MARK: - Stats row

    private var statsRow: some View {
        HStack(spacing: 10) {
            statPill(value: "\(playerVM.likedTracks.count)", label: "Liked")
            statPill(value: "\(playerVM.playlists.count)", label: "Playlists")
            statPill(value: "\(playerVM.recentlyPlayed.count)", label: "Played")
        }
    }

    private func statPill(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(themeManager.font(24, .black))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 9, weight: .black))
                .kerning(1)
                .foregroundStyle(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(card, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Liked section

    private var likedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LIKED TRACKS")
                .font(.system(size: 10, weight: .black)).kerning(2)
                .foregroundStyle(.white.opacity(0.3))
                .padding(.horizontal, 20)

            Button { showLiked = true } label: {
                HStack(spacing: 16) {
                    ZStack {
                        LinearGradient(
                            colors: [accent, accent.opacity(0.45)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                        Image(systemName: "heart.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Liked Songs")
                            .font(themeManager.font(16, .bold))
                            .foregroundStyle(.white)
                        Text(playerVM.likedTracks.isEmpty ? "No tracks yet" : "\(playerVM.likedTracks.count) tracks")
                            .font(themeManager.font(12))
                            .foregroundStyle(.white.opacity(0.4))
                    }

                    Spacer()

                    Button {
                        guard !playerVM.likedTracks.isEmpty else { return }
                        playerVM.playFromList(playerVM.likedTracks, startingWith: playerVM.likedTracks[0])
                        playerVM.showingNowPlaying = true
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(themeManager.current.onPrimary)
                            .frame(width: 42, height: 42)
                            .background(accent, in: Circle())
                    }
                    .buttonStyle(ScaleButtonStyle(scale: 0.9))
                    .disabled(playerVM.likedTracks.isEmpty)
                }
                .padding(16)
                .background(card, in: RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 20)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Playlists section

    private var playlistSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("PLAYLISTS")
                    .font(.system(size: 10, weight: .black)).kerning(2)
                    .foregroundStyle(.white.opacity(0.3))
                Spacer()
                Button { showCreateSheet = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus").font(.system(size: 11, weight: .bold))
                        Text("New").font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(accent)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(accent.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)

            if playerVM.playlists.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 36))
                        .foregroundStyle(.white.opacity(0.1))
                    Text("No playlists yet")
                        .font(themeManager.font(14))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("Tap + to create one")
                        .font(themeManager.font(12))
                        .foregroundStyle(.white.opacity(0.2))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                VStack(spacing: 0) {
                    ForEach(playerVM.playlists) { pl in
                        playlistRow(pl)
                        if pl.id != playerVM.playlists.last?.id {
                            Divider()
                                .background(Color.white.opacity(0.06))
                                .padding(.leading, 90)
                        }
                    }
                }
                .background(card, in: RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 20)
            }
        }
    }

    private func playlistRow(_ pl: LocalPlaylist) -> some View {
        Button { selectedPlaylist = pl } label: {
            HStack(spacing: 14) {
                playlistArtwork(pl)
                    .frame(width: 58, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 3) {
                    Text(pl.name)
                        .font(themeManager.font(15, .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("\(pl.tracks.count) track\(pl.tracks.count == 1 ? "" : "s")")
                        .font(themeManager.font(12))
                        .foregroundStyle(.white.opacity(0.4))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.2))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func playlistArtwork(_ pl: LocalPlaylist) -> some View {
        let urls = pl.tracks.prefix(4).compactMap { $0.thumbnailArtworkURL }
        if urls.count >= 4 {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 1), GridItem(.flexible(), spacing: 1)], spacing: 1) {
                ForEach(0..<4, id: \.self) { i in
                    AsyncImage(url: URL(string: urls[i])) { img in
                        img.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: { card }
                }
            }
            .background(card)
        } else if let urlStr = urls.first {
            AsyncImage(url: URL(string: urlStr)) { img in
                img.resizable().aspectRatio(contentMode: .fill)
            } placeholder: { card }
        } else {
            card.overlay(
                Image(systemName: "music.note.list")
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.2))
            )
        }
    }
}
