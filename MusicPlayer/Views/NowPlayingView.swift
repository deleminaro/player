import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @AppStorage("mp_audio_quality") private var audioQuality: AudioQuality = .lossless
    @State private var showLyrics        = false
    @State private var showQueue         = false
    @State private var showEQ            = false
    @State private var showSpeed         = false
    @State private var showAddToPlaylist = false
    @State private var isScrubbingClassic = false

    private let speeds: [Float] = [0.5, 0.75, 1.0, 1.15, 1.25, 1.5, 2.0]
    private var bg:       Color { themeManager.current.background }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            topBar
                .padding(.horizontal, 20)
                .padding(.top, 12)

            Spacer(minLength: 16)

            // Content pinned to bottom
            VStack(alignment: .leading, spacing: 0) {
                trackInfo
                waveformProgress
                    .padding(.top, 14)
                controlsRow
                    .padding(.top, 12)
                actionRow
                    .padding(.top, 14)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            // Full-bleed background — always fills entire sheet behind safe areas
            ZStack {
                bg
                if themeManager.backgroundStyle == .customPhoto,
                   let wallpaper = themeManager.customWallpaper {
                    Image(uiImage: wallpaper)
                        .resizable()
                        .scaledToFill()
                } else if let url = URL(string: playerVM.currentTrack?.highResArtworkURL ?? "") {
                    AsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                    } placeholder: { Color.clear }
                }
                LinearGradient(
                    colors: [.black.opacity(0.15), .black.opacity(0.35), .black.opacity(0.65), .black.opacity(0.88)],
                    startPoint: .top, endPoint: .bottom
                )
            }
            .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
        .presentationBackground(bg)
        .sheet(isPresented: $showLyrics) {
            if let t = playerVM.currentTrack { LyricsView(track: t).environmentObject(themeManager) }
        }
        .sheet(isPresented: $showQueue) {
            QueueView().environmentObject(playerVM)
        }
        .sheet(isPresented: $showEQ) {
            EqualizerView().environmentObject(playerVM).environmentObject(themeManager)
        }
        .sheet(isPresented: $showSpeed) {
            SpeedPickerSheet(currentSpeed: $playerVM.playbackSpeed) { spd in
                playerVM.setSpeed(spd)
            }
            .environmentObject(playerVM)
            .environmentObject(themeManager)
            .presentationDetents([.height(410)])
            .presentationBackground(.ultraThinMaterial)
            .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showAddToPlaylist) {
            if let track = playerVM.currentTrack {
                AddToPlaylistSheet(track: track)
                    .environmentObject(playerVM)
                    .environmentObject(themeManager)
                    .presentationDetents([.medium, .large])
                    .presentationBackground(themeManager.current.background)
                    .presentationCornerRadius(28)
            }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button { playerVM.showingNowPlaying = false } label: {
                ZStack {
                    Circle().fill(Color.white.opacity(0.12)).frame(width: 36, height: 36)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
            }

            Spacer()

            if let next = playerVM.nextTrack {
                HStack(spacing: 8) {
                    AsyncImage(url: URL(string: next.thumbnailArtworkURL ?? "")) { img in
                        img.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.15))
                    }
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 5))

                    VStack(alignment: .leading, spacing: 1) {
                        Text("NEXT")
                            .font(.system(size: 8, weight: .black)).kerning(1)
                            .foregroundStyle(.white.opacity(0.5))
                        Text(next.title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Color.white.opacity(0.12), in: Capsule())
                .frame(maxWidth: 180)
            }

            Spacer()

            Menu {
                Button { showEQ = true } label: { Label("Equalizer", systemImage: "slider.vertical.3") }
                Button { showQueue = true } label: { Label("Queue", systemImage: "list.bullet") }
                Button { showLyrics = true } label: { Label("Lyrics", systemImage: "quote.bubble") }
                Button { showAddToPlaylist = true } label: { Label("Add to Playlist", systemImage: "music.note.list") }
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

    // MARK: - Track info

    private var trackInfo: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                Text(playerVM.currentTrack?.title ?? "Not Playing")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text((playerVM.currentTrack?.username ?? "").uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(themeManager.current.primary)
                    .kerning(1.5)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                if let t = playerVM.currentTrack { playerVM.toggleLike(t) }
            } label: {
                Image(systemName: playerVM.currentTrack.map { playerVM.isLiked($0) } == true
                      ? "heart.fill" : "heart")
                    .font(.system(size: 18))
                    .foregroundStyle(playerVM.currentTrack.map { playerVM.isLiked($0) } == true
                                     ? .pink : .white.opacity(0.5))
            }
        }
    }

    // MARK: - Progress slider (switches on sliderType)

    @ViewBuilder
    private var waveformProgress: some View {
        switch themeManager.sliderType {
        case .waveform1: waveform1Progress
        case .waveform2: waveform2Progress
        case .classic:   classicProgress
        }
    }

    // Waveform I — random-height bars, top-growing (unique per song)
    private var waveform1Progress: some View {
        let progress = playerVM.duration > 0 ? playerVM.currentTime / playerVM.duration : 0
        let bars = waveformHeights(for: playerVM.currentTrack?.id ?? 0)

        return VStack(spacing: 6) {
            GeometryReader { geo in
                Canvas { ctx, size in
                    let count = CGFloat(bars.count)
                    let step  = size.width / count
                    let barW  = max(2, step * 0.72)
                    for (i, h) in bars.enumerated() {
                        let filled = Double(i) / Double(bars.count) < progress
                        let barH = h * size.height
                        let rect = CGRect(
                            x: CGFloat(i) * step + (step - barW) / 2,
                            y: (size.height - barH) / 2,
                            width: barW, height: barH
                        )
                        ctx.fill(Path(roundedRect: rect, cornerRadius: barW / 2),
                                 with: .color(filled ? themeManager.current.primary : Color.white.opacity(0.22)))
                    }
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                    let pct = max(0, min(1, v.location.x / geo.size.width))
                    playerVM.seek(to: pct * playerVM.duration)
                })
            }
            .frame(height: 40)
            timeLabels
        }
    }

    // Waveform II — symmetric bars growing from center (unique per song)
    private var waveform2Progress: some View {
        let progress = playerVM.duration > 0 ? playerVM.currentTime / playerVM.duration : 0
        let bars = waveformHeights(for: playerVM.currentTrack?.id ?? 0)

        return VStack(spacing: 6) {
            GeometryReader { geo in
                Canvas { ctx, size in
                    let count = CGFloat(bars.count)
                    let step  = size.width / count
                    let barW  = max(2, step * 0.65)
                    let cy    = size.height / 2
                    for (i, h) in bars.enumerated() {
                        let filled = Double(i) / Double(bars.count) < progress
                        let halfH  = h * cy * 0.92
                        let rect = CGRect(
                            x: CGFloat(i) * step + (step - barW) / 2,
                            y: cy - halfH,
                            width: barW, height: halfH * 2
                        )
                        ctx.fill(Path(roundedRect: rect, cornerRadius: barW / 2),
                                 with: .color(filled ? themeManager.current.primary : Color.white.opacity(0.22)))
                    }
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                    let pct = max(0, min(1, v.location.x / geo.size.width))
                    playerVM.seek(to: pct * playerVM.duration)
                })
            }
            .frame(height: 40)
            timeLabels
        }
    }

    // Classic — iOS 26 / Apple Music thick capsule, expands on scrub
    private var classicProgress: some View {
        let progress = playerVM.duration > 0 ? playerVM.currentTime / playerVM.duration : 0

        return VStack(spacing: 10) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: isScrubbingClassic ? 14 : 5)
                    Capsule()
                        .fill(Color.white)
                        .frame(width: max(0, geo.size.width * CGFloat(progress)),
                               height: isScrubbingClassic ? 14 : 5)
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isScrubbingClassic)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            isScrubbingClassic = true
                            let pct = max(0, min(1, v.location.x / geo.size.width))
                            playerVM.seek(to: pct * playerVM.duration)
                        }
                        .onEnded { _ in isScrubbingClassic = false }
                )
            }
            .frame(height: 20)
            timeLabels
        }
    }

    private var timeLabels: some View {
        HStack {
            Text(formatTime(playerVM.currentTime))
            Spacer()
            Text(formatTime(max(0, playerVM.duration - playerVM.currentTime)))
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.white.opacity(0.45))
        .monospacedDigit()
    }

    // MARK: - Controls

    private var controlsRow: some View {
        HStack {
            // Shuffle
            Button { playerVM.isShuffling.toggle() } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(playerVM.isShuffling ? themeManager.current.primary : .white.opacity(0.4))
            }

            Spacer()

            // Previous
            Button { playerVM.skipPrevious() } label: {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Spacer()

            // Play / Pause
            Button { playerVM.togglePlayPause() } label: {
                ZStack {
                    Circle().fill(.white).frame(width: 56, height: 56)
                    if playerVM.playerState == .loading {
                        ProgressView().tint(.black).scaleEffect(1.0)
                    } else {
                        Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.black)
                            .offset(x: playerVM.isPlaying ? 0 : 2)
                    }
                }
            }

            Spacer()

            // Next
            Button { playerVM.skipNext() } label: {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Spacer()

            // Repeat
            Button { playerVM.isRepeating.toggle() } label: {
                Image(systemName: playerVM.isRepeating ? "repeat.1" : "repeat")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(playerVM.isRepeating ? themeManager.current.primary : .white.opacity(0.4))
            }
        }
    }

    // MARK: - Action row

    private var actionRow: some View {
        HStack {
            // Left: like, lyrics, chat
            HStack(spacing: 18) {
                Button { showLyrics = true } label: {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Button { showEQ = true } label: {
                    Image(systemName: "slider.vertical.3")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color.white.opacity(0.1), in: Capsule())

            Spacer()

            // Centre: lossless badge (only when quality = lossless and track has Opus)
            if audioQuality == .lossless,
               playerVM.currentTrack?.media?.transcodings.contains(where: { $0.format.mimeType.contains("opus") }) == true {
                VStack(spacing: 2) {
                    Image(systemName: "waveform")
                        .font(.system(size: 11, weight: .bold))
                    Text("LOSSLESS")
                        .font(.system(size: 8, weight: .black)).kerning(1.2)
                }
                .foregroundStyle(themeManager.current.primary)
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(themeManager.current.primary.opacity(0.15), in: Capsule())
                .overlay(Capsule().stroke(themeManager.current.primary.opacity(0.35), lineWidth: 1))
            }

            Spacer()

            // Right: speed, queue
            HStack(spacing: 12) {
                Button { showSpeed = true } label: {
                    Image(systemName: speedIcon(playerVM.playbackSpeed))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(playerVM.playbackSpeed == 1.0 ? .white.opacity(0.6) : themeManager.current.primary)
                }

                Button { showQueue = true } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 18))
                            .foregroundStyle(.white.opacity(0.6))
                        if !playerVM.queue.isEmpty {
                            Text("\(playerVM.queue.count)")
                                .font(.system(size: 8, weight: .black))
                                .foregroundStyle(.black)
                                .padding(3)
                                .background(themeManager.current.primary, in: Circle())
                                .offset(x: 8, y: -6)
                        }
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color.white.opacity(0.1), in: Capsule())
        }
    }

    // MARK: - Helpers

    private func formatTime(_ s: Double) -> String {
        guard s.isFinite else { return "0:00" }
        let t = Int(max(0, s))
        return String(format: "%d:%02d", t / 60, t % 60)
    }

    private func speedIcon(_ s: Float) -> String {
        if s < 0.99 { return "person.wave.2" }
        if s > 1.01 { return "speedometer" }
        return "play.circle"
    }

    private func waveformHeights(for seed: Int) -> [CGFloat] {
        var rng = seed &* 1664525 &+ 1013904223
        return (0..<52).map { _ in
            rng = rng &* 1664525 &+ 1013904223
            let v = CGFloat((rng >> 16) & 0xFFFF) / 65535.0
            return 0.2 + v * 0.8
        }
    }
}

// MARK: - Add to playlist sheet

struct AddToPlaylistSheet: View {
    let track: Track
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    @State private var showCreate    = false
    @State private var newName       = ""
    @State private var toastMessage: String?
    @State private var toastTask:    Task<Void, Never>?

    private var bg:     Color { themeManager.current.background }
    private var bgCard: Color { themeManager.current.card }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Track preview
                    HStack(spacing: 14) {
                        AsyncImage(url: URL(string: track.thumbnailArtworkURL ?? "")) { img in
                            img.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 10).fill(bgCard)
                        }
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(track.title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white).lineLimit(1)
                            Text(track.username.uppercased())
                                .font(.system(size: 10, weight: .semibold)).kerning(1)
                                .foregroundStyle(themeManager.current.primary).lineLimit(1)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20).padding(.vertical, 16)
                    .background(bgCard, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 20)

                    // Create new playlist row
                    Button {
                        showCreate = true
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12).fill(themeManager.current.primary.opacity(0.15))
                                    .frame(width: 52, height: 52)
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(themeManager.current.primary)
                            }
                            Text("New Playlist")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .padding(.horizontal, 20).padding(.vertical, 12)
                    }

                    Divider()
                        .background(Color.white.opacity(0.07))
                        .padding(.horizontal, 20).padding(.vertical, 4)

                    // Existing playlists
                    if playerVM.playlists.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 32))
                                .foregroundStyle(.white.opacity(0.15))
                            Text("NO PLAYLISTS YET")
                                .font(.system(size: 11, weight: .black)).kerning(2)
                                .foregroundStyle(.white.opacity(0.3))
                        }
                        .padding(.top, 40)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(playerVM.playlists) { pl in
                                let alreadyAdded = pl.tracks.contains { $0.id == track.id }
                                Button {
                                    guard !alreadyAdded else { return }
                                    playerVM.addTrackToPlaylist(track, playlistID: pl.id)
                                    showToast("Added to \(pl.name)")
                                } label: {
                                    HStack(spacing: 14) {
                                        playlistArtwork(pl)
                                            .frame(width: 52, height: 52)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(pl.name)
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(.white).lineLimit(1)
                                            Text("\(pl.tracks.count) tracks")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.white.opacity(0.4))
                                        }
                                        Spacer()
                                        if alreadyAdded {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 18))
                                                .foregroundStyle(themeManager.current.primary)
                                        }
                                    }
                                    .padding(.horizontal, 20).padding(.vertical, 12)
                                    .opacity(alreadyAdded ? 0.5 : 1)
                                }
                                .buttonStyle(.plain)

                                Divider()
                                    .background(Color.white.opacity(0.05))
                                    .padding(.leading, 86)
                            }
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            .background(bg.ignoresSafeArea())
            .navigationTitle("Add to Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(themeManager.current.primary)
                }
            }
            .toolbarBackground(bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .preferredColorScheme(.dark)
        }
        .overlay(alignment: .bottom) {
            if let msg = toastMessage {
                Text(msg)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: toastMessage)
        .alert("New Playlist", isPresented: $showCreate) {
            TextField("Playlist name", text: $newName)
            Button("Create") {
                let name = newName.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return }
                let pl = playerVM.createPlaylist(name: name)
                playerVM.addTrackToPlaylist(track, playlistID: pl.id)
                newName = ""
                showToast("Added to \(name)")
            }
            Button("Cancel", role: .cancel) { newName = "" }
        }
    }

    @ViewBuilder
    private func playlistArtwork(_ pl: LocalPlaylist) -> some View {
        let urls = pl.mosaicURLs
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
            ZStack { bgCard; Image(systemName: "music.note.list").foregroundStyle(.white.opacity(0.3)) }
        }
    }

    private func showToast(_ message: String) {
        toastTask?.cancel()
        toastMessage = message
        toastTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            toastMessage = nil
        }
    }
}

// MARK: - Speed picker sheet

struct SpeedPickerSheet: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var currentSpeed: Float
    let onSelect: (Float) -> Void
    @Environment(\.dismiss) var dismiss

    private struct SpeedMode {
        let label: String
        let icon: String
        let speed: Float
    }
    private let modes: [SpeedMode] = [
        SpeedMode(label: "Slowed",   icon: "person.wave.2",  speed: 0.75),
        SpeedMode(label: "Default",  icon: "play.circle",    speed: 1.0),
        SpeedMode(label: "Speedup",  icon: "speedometer",    speed: 1.25),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.white.opacity(0.25))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)

            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(playerVM.isPitchPreserved ? themeManager.current.primary : .white.opacity(0.4))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("PITCH LOCK")
                            .font(.system(size: 11, weight: .black)).kerning(1.5)
                            .foregroundStyle(.white)
                        Text(playerVM.isPitchPreserved ? "Pitch preserved" : "Natural pitch shift")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { playerVM.isPitchPreserved },
                    set: { _ in playerVM.togglePitchPreservation() }
                ))
                .toggleStyle(SwitchToggleStyle(tint: themeManager.current.primary))
                .labelsHidden()
            }
            .padding(.horizontal, 20).padding(.vertical, 14)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            HStack(spacing: 12) {
                ForEach(modes, id: \.speed) { mode in
                    let selected = abs(currentSpeed - mode.speed) < 0.01
                    Button {
                        onSelect(mode.speed)
                        currentSpeed = mode.speed
                    } label: {
                        VStack(spacing: 10) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 28, weight: .regular))
                                .foregroundStyle(selected ? .black : .white)
                            Text(mode.label)
                                .font(.custom("Courier", size: 16)).bold()
                                .foregroundStyle(selected ? .black : .white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 22)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(selected ? .white : Color.white.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)

            // Live waveform progress
            waveformBar
                .padding(.horizontal, 24)
                .padding(.top, 28)

            Spacer()
        }
        .preferredColorScheme(.dark)
    }

    private var waveformBar: some View {
        let speedMin: Float = 0.5
        let speedMax: Float = 2.0
        let progress = Double((currentSpeed - speedMin) / (speedMax - speedMin))
        let bars = waveformHeights(for: playerVM.currentTrack?.id ?? 0)

        return VStack(spacing: 10) {
            GeometryReader { geo in
                Canvas { ctx, size in
                    let count = CGFloat(bars.count)
                    let step  = size.width / count
                    let barW  = max(1.5, step * 0.55)
                    for (i, h) in bars.enumerated() {
                        let filled = Double(i) / Double(bars.count) < progress
                        let barH = h * size.height
                        let rect = CGRect(
                            x: CGFloat(i) * step + (step - barW) / 2,
                            y: (size.height - barH) / 2,
                            width: barW, height: barH
                        )
                        ctx.fill(Path(roundedRect: rect, cornerRadius: barW / 2),
                                 with: .color(filled ? .white : Color.white.opacity(0.2)))
                    }
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                    let pct   = max(0.0, min(1.0, v.location.x / geo.size.width))
                    var speed = Float(pct) * (speedMax - speedMin) + speedMin
                    // Snap to preset if within ±0.04
                    for m in modes where abs(speed - m.speed) < 0.04 { speed = m.speed; break }
                    speed = (speed * 100).rounded() / 100
                    currentSpeed = speed
                    onSelect(speed)
                })
            }
            .frame(height: 44)

            Text(currentSpeed == 1.0 ? "1×" : "\(String(format: "%g", currentSpeed))×")
                .font(.custom("Courier New", size: 14)).bold()
                .foregroundStyle(.white.opacity(0.55))
                .monospacedDigit()
        }
    }

    private func waveformHeights(for seed: Int) -> [CGFloat] {
        var rng = seed &* 1664525 &+ 1013904223
        return (0..<52).map { _ in
            rng = rng &* 1664525 &+ 1013904223
            let v = CGFloat((rng >> 16) & 0xFFFF) / 65535.0
            return 0.2 + v * 0.8
        }
    }
}
