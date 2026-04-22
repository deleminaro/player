import SwiftUI
import UIKit

struct LibraryView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showLiked        = false
    @State private var showCreateSheet  = false
    @State private var newPlaylistName  = ""
    @State private var selectedPlaylist: LocalPlaylist?

    private var bg:      Color { themeManager.current.background }
    private var bgCard:  Color { themeManager.current.card }

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
                        .font(.system(size: 20, weight: .black)).foregroundStyle(.white)
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
        .frame(height: 170)
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
                    .font(.system(size: 14, weight: .black)).foregroundStyle(.white)
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
    private var bg:    Color { themeManager.current.card }

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

    private var bg:     Color { themeManager.current.background }
    private var bgCard: Color { themeManager.current.card }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header artwork
                    artworkHeader
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal, 50)
                        .padding(.top, 16)
                        .padding(.bottom, 12)

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

    private var bg: Color { themeManager.current.background }

    var body: some View {
        NavigationStack {
            List(playerVM.likedTracks) { track in
                LikedTrackRow(track: track)
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
                    .listRowInsets(EdgeInsets())
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

// MARK: - Liked track row with download menu

private struct LikedTrackRow: View {
    let track: Track
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showDownload = false

    var body: some View {
        HStack(spacing: 14) {
            ArtworkThumbnail(url: track.thumbnailArtworkURL)

            VStack(alignment: .leading, spacing: 3) {
                Text(track.title.uppercased())
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.white).lineLimit(1)
                Text(track.username.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(themeManager.current.primary)
                    .kerning(1.5).lineLimit(1)
            }

            Spacer()

            Text(track.durationFormatted)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.3))

            Button {
                showDownload = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
        .sheet(isPresented: $showDownload) {
            DownloadOptionsSheet(track: track)
                .environmentObject(themeManager)
                .presentationDetents([.fraction(0.55)])
                .presentationBackground(Color(red: 0.075, green: 0.075, blue: 0.075))
                .presentationCornerRadius(28)
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
                // Save to cache
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

                // Download offline
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

                // Save to folder
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

            // Back
            Button { dismiss() } label: {
                Text("Back")
                    .font(.system(size: 15, weight: .black)).kerning(1)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
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
        let bgCard = Color(red: 0.110, green: 0.110, blue: 0.110)
        Button(action: { if !done && !busy { action() } }) {
            HStack(spacing: 16) {
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 12).fill(bgCard).frame(width: 58, height: 58)
                    VStack(spacing: 3) {
                        Image(systemName: icon)
                            .font(.system(size: 22, weight: .regular))
                            .foregroundStyle(.white)
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
                    Text(title)
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 12)).foregroundStyle(.white.opacity(0.4))
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
