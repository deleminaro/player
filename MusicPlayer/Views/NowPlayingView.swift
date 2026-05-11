import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showLyrics        = false
    @State private var showQueue         = false
    @State private var showEQ            = false
    @State private var showSpeed         = false
    @State private var showAddToPlaylist = false
    @State private var showSleepTimer    = false
    @State private var showFullArtwork   = false
    @State private var isScrubbing       = false
    @State private var hasAppeared       = false
    @State private var waveProgress: Double = 0
    @State private var dragOffset: CGFloat  = 0
    @State private var canvasPhase: Bool    = false
    @State private var waveformData: [CGFloat] = []   // real SoundCloud waveform

    private let speeds: [Float] = [0.5, 0.75, 1.0, 1.15, 1.25, 1.5, 2.0]
    private var bg:       Color { themeManager.current.background }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            topBar
                .padding(.horizontal, 20)
                .padding(.top, 12)

            // Cover artwork — fills available space, no artificial height cap
            coverArtwork
                .padding(.horizontal, 28)
                .padding(.top, 8)
                .id(playerVM.currentTrack?.id)
                .transition(.scale(scale: 0.94).combined(with: .opacity))
                .animation(.spring(response: 0.45, dampingFraction: 0.8), value: playerVM.currentTrack?.id)
                .scaleEffect(playerVM.isPlaying ? 1.0 : 0.94)
                .animation(.spring(response: 0.5, dampingFraction: 0.72), value: playerVM.isPlaying)
                .onTapGesture { showFullArtwork = true }

            Spacer(minLength: 12)

            // Content pinned to bottom
            VStack(alignment: .leading, spacing: 0) {
                trackInfo
                waveformProgress
                    .padding(.top, 14)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 12)
                    .animation(.spring(response: 0.55, dampingFraction: 0.82).delay(0.15), value: hasAppeared)
                controlsRow
                    .padding(.top, 12)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 16)
                    .animation(.spring(response: 0.55, dampingFraction: 0.82).delay(0.22), value: hasAppeared)
                actionRow
                    .padding(.top, 14)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 20)
                    .animation(.spring(response: 0.55, dampingFraction: 0.82).delay(0.28), value: hasAppeared)

            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
            .onAppear {
                hasAppeared = false
                withAnimation { hasAppeared = true }
                waveProgress = displayDuration > 0 ? playerVM.currentTime / displayDuration : 0
                loadWaveform()
            }
            .onChange(of: playerVM.currentTrack?.id) { _, _ in
                hasAppeared = false
                withAnimation { hasAppeared = true }
                waveProgress = 0
                waveformData = []
                loadWaveform()
            }
            .onChange(of: playerVM.currentTime) { _, t in
                guard !isScrubbing else { return }
                let p = displayDuration > 0 ? t / displayDuration : 0
                withAnimation(.linear(duration: 0.5)) { waveProgress = p }
            }
        }
        .offset(y: max(0, dragOffset))
        .opacity(Double(1 - dragOffset / 500))
        .gesture(
            DragGesture(minimumDistance: 20)
                .onChanged { v in
                    guard v.translation.height > 0,
                          abs(v.translation.height) > abs(v.translation.width) else { return }
                    dragOffset = v.translation.height
                }
                .onEnded { v in
                    if v.translation.height > 110 || v.predictedEndTranslation.height > 260 {
                        playerVM.showingNowPlaying = false
                    } else {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                bg
                if let customBg = playerVM.currentTrack.flatMap({ playerVM.customArtwork(for: $0.id) }) {
                    Image(uiImage: customBg)
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(canvasPhase ? 1.12 : 1.0)
                        .offset(x: canvasPhase ? 18 : -18, y: canvasPhase ? -12 : 12)
                        .id(playerVM.currentTrack?.id)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.6), value: playerVM.currentTrack?.id)
                } else if let url = URL(string: playerVM.currentTrack?.highResArtworkURL ?? "") {
                    AsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                           .scaleEffect(canvasPhase ? 1.12 : 1.0)
                           .offset(x: canvasPhase ? 18 : -18, y: canvasPhase ? -12 : 12)
                    } placeholder: { Color.clear }
                        .id(playerVM.currentTrack?.id)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.6), value: playerVM.currentTrack?.id)
                }
                LinearGradient(
                    colors: [.black.opacity(0.15), .black.opacity(0.35), .black.opacity(0.65), .black.opacity(0.88)],
                    startPoint: .top, endPoint: .bottom
                )
            }
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.easeInOut(duration: 16).repeatForever(autoreverses: true)) {
                    canvasPhase = true
                }
            }
        }
        .fullScreenCover(isPresented: $showFullArtwork) {
            FullArtworkView(track: playerVM.currentTrack)
                .environmentObject(themeManager)
        }
        .preferredColorScheme(.dark)
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
        .sheet(isPresented: $showSleepTimer) {
            SleepTimerSheet()
                .environmentObject(playerVM)
                .environmentObject(themeManager)
                .presentationDetents([.height(340)])
                .presentationDragIndicator(.visible)
                .presentationBackground(themeManager.current.card)
                .presentationCornerRadius(24)
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button { playerVM.showingNowPlaying = false } label: {
                ZStack {
                    Circle().fill(Color.white.opacity(0.12)).frame(width: 40, height: 40)
                    Image(systemName: "chevron.down")
                        .font(.app(13, .bold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.88))

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
                        Text("Next")
                            .font(themeManager.font(8))
                            .foregroundStyle(.white.opacity(0.5))
                        Text(next.title)
                            .font(themeManager.font(11, .semibold))
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
                Button { showSleepTimer = true } label: { Label("Sleep Timer", systemImage: "moon.zzz") }
                Button { showQueue = true } label: { Label("Queue", systemImage: "list.bullet") }
                Button { showLyrics = true } label: { Label("Lyrics", systemImage: "quote.bubble") }
                Button { showAddToPlaylist = true } label: { Label("Add to Playlist", systemImage: "music.note.list") }
            } label: {
                ZStack {
                    Circle().fill(Color.white.opacity(0.12)).frame(width: 40, height: 40)
                    Image(systemName: "ellipsis")
                        .font(.app(14, .bold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.88))
        }
    }

    // MARK: - Cover artwork

    @ViewBuilder
    private var coverArtwork: some View {
        switch themeManager.coverStyle {
        case .hidden:
            EmptyView()
        case .customPhoto:
            if let img = themeManager.customCoverImage {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.5), radius: 24, y: 10)
                    .frame(maxWidth: .infinity)
            } else {
                albumArtSquare
            }
        case .albumArt:
            albumArtSquare
        }
    }

    private var albumArtSquare: some View {
        let track = playerVM.currentTrack
        let customImg: UIImage? = track.map { playerVM.customArtwork(for: $0.id) } ?? nil
        let artworkURLStr: String? = track?.highResArtworkURL ?? track?.artworkURL

        return ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.08))
            if let img = customImg {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if let urlStr = artworkURLStr, let url = URL(string: urlStr) {
                AsyncImage(url: url) { img in
                    img.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "music.note")
                        .font(.app(48, .ultraLight))
                        .foregroundStyle(.white.opacity(0.2))
                }
            } else {
                Image(systemName: "music.note")
                    .font(.app(48, .ultraLight))
                    .foregroundStyle(.white.opacity(0.2))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.5), radius: 24, y: 10)
    }

    // MARK: - Track info

    private var trackInfo: some View {
        let track  = playerVM.currentTrack
        let accent = themeManager.current.primary
        return VStack(alignment: .leading, spacing: 4) {
            Text(track?.title ?? "Not Playing")
                .font(themeManager.font(22, .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: track?.id)

            HStack(spacing: 8) {
                Text(track?.username ?? "")
                    .font(themeManager.font(14))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.3).delay(0.05), value: track?.id)
                if track?.source == .spotify {
                    Text("PREVIEW")
                        .font(.app(8, .bold)).kerning(0.5)
                        .foregroundStyle(Color(red: 0.11, green: 0.73, blue: 0.33))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color(red: 0.11, green: 0.73, blue: 0.33).opacity(0.15), in: Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Progress slider (switches on sliderType)

    @ViewBuilder
    private var waveformProgress: some View {
        switch themeManager.sliderType {
        case .waveform2: waveform2Progress
        case .classic:   classicProgress
        case .glimmer:   glimmerProgress
        }
    }

    // Waveform — symmetric bars growing from center; uses real SoundCloud data when available
    private var waveform2Progress: some View {
        let bars  = effectiveWaveformBars
        let accent = themeManager.current.primary

        return VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Canvas { ctx, size in
                        let step = size.width / CGFloat(bars.count)
                        let barW = max(2, step * 0.65)
                        let cy   = size.height / 2
                        for (i, h) in bars.enumerated() {
                            let halfH = h * cy * 0.92
                            let rect = CGRect(x: CGFloat(i)*step+(step-barW)/2, y: cy-halfH, width: barW, height: halfH*2)
                            ctx.fill(Path(roundedRect: rect, cornerRadius: barW/2), with: .color(Color.white.opacity(0.22)))
                        }
                    }
                    Canvas { ctx, size in
                        let step = size.width / CGFloat(bars.count)
                        let barW = max(2, step * 0.65)
                        let cy   = size.height / 2
                        for (i, h) in bars.enumerated() {
                            let halfH = h * cy * 0.92
                            let rect = CGRect(x: CGFloat(i)*step+(step-barW)/2, y: cy-halfH, width: barW, height: halfH*2)
                            ctx.fill(Path(roundedRect: rect, cornerRadius: barW/2), with: .color(accent))
                        }
                    }
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: max(0, geo.size.width * waveProgress))
                    }
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        isScrubbing = true
                        let p = max(0, min(1, v.location.x / geo.size.width))
                        waveProgress = p
                        playerVM.seek(to: p * displayDuration)
                    }
                    .onEnded { _ in isScrubbing = false }
                )
            }
            .frame(height: 40)
            timeLabels
        }
    }

    // Classic — thick capsule, expands on scrub
    private var classicProgress: some View {
        let trackH: CGFloat = isScrubbing ? 14 : 5

        return VStack(spacing: 10) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: trackH)
                    Capsule()
                        .fill(Color.white)
                        .frame(width: max(0, geo.size.width * waveProgress), height: trackH)
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isScrubbing)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            isScrubbing = true
                            let p = max(0, min(1, v.location.x / geo.size.width))
                            waveProgress = p
                            playerVM.seek(to: p * displayDuration)
                        }
                        .onEnded { _ in isScrubbing = false }
                )
            }
            .frame(height: 20)
            timeLabels
        }
    }

    // Glimmer — capsule with a shimmer highlight sweeping left→right
    private var glimmerProgress: some View {
        let trackH: CGFloat = isScrubbing ? 14 : 8
        let accent = themeManager.current.primary
        return VStack(spacing: 10) {
            TimelineView(.animation(minimumInterval: 1.0 / 20)) { tl in
                let phase = CGFloat(
                    tl.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: 2.0) / 2.0
                )
                GeometryReader { geo in
                    let fillW = max(0, geo.size.width * waveProgress)
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: trackH)
                        if fillW > 0 {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        stops: [
                                            .init(color: accent,                   location: 0),
                                            .init(color: accent,                   location: max(0, phase - 0.18)),
                                            .init(color: Color.white.opacity(0.90), location: phase),
                                            .init(color: accent,                   location: min(1, phase + 0.18)),
                                            .init(color: accent,                   location: 1),
                                        ],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .frame(width: fillW, height: trackH)
                        }
                        Circle()
                            .fill(.white)
                            .frame(width: isScrubbing ? 20 : 16,
                                   height: isScrubbing ? 20 : 16)
                            .shadow(color: accent.opacity(0.55), radius: 6)
                            .offset(x: max(0, fillW - (isScrubbing ? 10 : 8)))
                    }
                    .animation(.spring(response: 0.28, dampingFraction: 0.72),
                               value: isScrubbing)
                    .frame(maxHeight: .infinity, alignment: .center)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            isScrubbing = true
                            let p = max(0, min(1, v.location.x / geo.size.width))
                            waveProgress = p
                            playerVM.seek(to: p * displayDuration)
                        }
                        .onEnded { _ in isScrubbing = false }
                    )
                }
                .frame(height: 28)
            }
            timeLabels
        }
    }

    private var timeLabels: some View {
        HStack {
            Text(formatTime(playerVM.currentTime))
            Spacer()
            Text(formatTime(max(0, displayDuration - playerVM.currentTime)))
        }
        .font(themeManager.font(11, .medium))
        .foregroundStyle(.white.opacity(0.4))
        .monospacedDigit()
    }

    // Use track metadata duration when AVPlayer reports an unreliable value (e.g. HLS streams)
    private var displayDuration: Double {
        let fromTrack  = Double(playerVM.currentTrack?.duration ?? 0) / 1000.0
        let fromPlayer = playerVM.duration
        if fromTrack > 0 && (fromPlayer <= 0 || !fromPlayer.isFinite || fromPlayer > fromTrack * 4) {
            return fromTrack
        }
        return fromPlayer > 0 ? fromPlayer : fromTrack
    }

    // MARK: - Controls

    private var controlsRow: some View {
        HStack(spacing: 0) {
            // Shuffle
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { playerVM.isShuffling.toggle() }
            } label: {
                Image(systemName: "shuffle")
                    .font(.app(16, .semibold))
                    .foregroundStyle(playerVM.isShuffling ? themeManager.current.primary : .white.opacity(0.45))
                    .frame(width: 46, height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(playerVM.isShuffling ? themeManager.current.primary.opacity(0.18) : Color.clear)
                            .animation(.easeInOut(duration: 0.2), value: playerVM.isShuffling)
                    )
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.85))
            .sensoryFeedback(.selection, trigger: playerVM.isShuffling)

            Spacer()

            // Previous
            Button { playerVM.skipPrevious() } label: {
                Image(systemName: "backward.end.fill")
                    .font(.app(26, .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.85))

            Spacer()

            // Play / Pause
            Button { playerVM.togglePlayPause() } label: {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 70, height: 70)
                        .shadow(color: .white.opacity(0.15), radius: 16, y: 4)
                    if playerVM.playerState == .loading {
                        ProgressView().tint(.black).scaleEffect(1.1)
                    } else {
                        Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                            .font(.app(26, .bold))
                            .foregroundStyle(.black)
                            .offset(x: playerVM.isPlaying ? 0 : 2)
                            .contentTransition(.symbolEffect(.replace))
                            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: playerVM.isPlaying)
                    }
                }
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.93))
            .sensoryFeedback(.impact(weight: .heavy), trigger: playerVM.isPlaying)

            Spacer()

            // Next
            Button { playerVM.skipNext() } label: {
                Image(systemName: "forward.end.fill")
                    .font(.app(26, .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.85))
            .sensoryFeedback(.impact(weight: .medium), trigger: playerVM.currentTrack?.id)

            Spacer()

            // Repeat — cycles off → one → all
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    playerVM.repeatMode = playerVM.repeatMode.next
                }
            } label: {
                let active = playerVM.repeatMode != .off
                ZStack(alignment: .topTrailing) {
                    Image(systemName: playerVM.repeatMode.icon)
                        .font(.app(16, .semibold))
                        .foregroundStyle(active ? themeManager.current.primary : .white.opacity(0.45))
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 46, height: 46)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(active ? themeManager.current.primary.opacity(0.18) : Color.clear)
                        )
                    if playerVM.repeatMode == .all {
                        Circle()
                            .fill(themeManager.current.primary)
                            .frame(width: 7, height: 7)
                            .offset(x: -2, y: 2)
                    }
                }
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.85))
            .sensoryFeedback(.selection, trigger: playerVM.repeatMode)
        }
    }

    // MARK: - Action row (two pill containers)

    private var actionRow: some View {
        let liked  = playerVM.currentTrack.map { playerVM.isLiked($0) } == true
        let track  = playerVM.currentTrack
        let accent = themeManager.current.primary
        let qCount = playerVM.queue.count

        return HStack(spacing: 10) {
            // Left pill: like | lyrics | add-to-playlist
            HStack(spacing: 20) {
                Button {
                    if let t = track { playerVM.toggleLike(t) }
                } label: {
                    Image(systemName: liked ? "heart.fill" : "heart")
                        .font(.app(19))
                        .foregroundStyle(liked ? .pink : .white.opacity(0.7))
                        .scaleEffect(liked ? 1.1 : 1.0)
                        .contentTransition(.symbolEffect(.replace))
                        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: liked)
                }
                .buttonStyle(ScaleButtonStyle(scale: 0.85))
                .sensoryFeedback(.impact(weight: .medium), trigger: liked)

                Button { showLyrics = true } label: {
                    Image(systemName: "quote.bubble")
                        .font(.app(19))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(ScaleButtonStyle(scale: 0.85))

                Button { showAddToPlaylist = true } label: {
                    Image(systemName: "music.note.list")
                        .font(.app(19))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(ScaleButtonStyle(scale: 0.85))
            }
            .padding(.horizontal, 20).padding(.vertical, 14)
            .background(Color.white.opacity(0.1), in: Capsule())

            Spacer()

            // Right pill: speed | queue
            HStack(spacing: 16) {
                Button { showSpeed = true } label: {
                    Text(playerVM.playbackSpeed == 1.0 ? "1×"
                         : "\(String(format: "%g", playerVM.playbackSpeed))×")
                        .font(themeManager.font(14, .semibold))
                        .foregroundStyle(playerVM.playbackSpeed == 1.0 ? .white.opacity(0.7) : accent)
                        .monospacedDigit()
                }
                .buttonStyle(ScaleButtonStyle(scale: 0.85))

                Button { showQueue = true } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "list.bullet")
                            .font(.app(19))
                            .foregroundStyle(.white.opacity(0.7))
                        if qCount > 0 {
                            Text("\(qCount)")
                                .font(.app(8, .black))
                                .foregroundStyle(.black)
                                .padding(3)
                                .background(accent, in: Circle())
                                .offset(x: 10, y: -8)
                        }
                    }
                }
                .buttonStyle(ScaleButtonStyle(scale: 0.85))
            }
            .padding(.horizontal, 20).padding(.vertical, 14)
            .background(Color.white.opacity(0.1), in: Capsule())
        }
    }

    // MARK: - Helpers

    private var sleepTimerLabel: String {
        if let end = playerVM.sleepTimerEnd {
            let secs = Int(end.timeIntervalSinceNow)
            guard secs > 0 else { return "Sleep" }
            if secs < 3600 { return "\(secs / 60)m" }
            return "\(secs / 3600)h"
        }
        switch playerVM.sleepTimerMode {
        case .endOfTrack: return "Track"
        default: return "Sleep"
        }
    }

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

    // Returns real waveform data if loaded, otherwise a seeded pseudo-random fallback
    private var effectiveWaveformBars: [CGFloat] {
        if !waveformData.isEmpty { return waveformData }
        return pseudoWaveform(for: playerVM.currentTrack?.id ?? 0)
    }

    private func pseudoWaveform(for seed: Int) -> [CGFloat] {
        var rng = seed &* 1664525 &+ 1013904223
        return (0..<52).map { _ in
            rng = rng &* 1664525 &+ 1013904223
            let v = CGFloat((rng >> 16) & 0xFFFF) / 65535.0
            return 0.2 + v * 0.8
        }
    }

    private func loadWaveform() {
        guard let rawURL = playerVM.currentTrack?.waveformURL else { return }
        // SoundCloud serves waveforms as PNG; the JSON variant uses the same URL with .json
        let jsonURLStr = rawURL.replacingOccurrences(of: ".png", with: ".json")
        guard let url = URL(string: jsonURLStr) else { return }
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
            struct WF: Decodable { let samples: [Int]; let height: Int }
            guard let wf = try? JSONDecoder().decode(WF.self, from: data), wf.height > 0 else { return }
            let maxH = CGFloat(wf.height)
            // Downsample to 52 bars
            let raw  = wf.samples.map { CGFloat($0) / maxH }
            let step = max(1, raw.count / 52)
            let bars = stride(from: 0, to: raw.count, by: step).prefix(52).map {
                max(0.07, raw[$0])
            }
            await MainActor.run { waveformData = Array(bars) }
        }
    }
}

// MARK: - Scale button style

struct ScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.88
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
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
                                .font(themeManager.font(14, .semibold))
                                .foregroundStyle(.white).lineLimit(1)
                            Text(track.username)
                                .font(themeManager.font(12))
                                .foregroundStyle(themeManager.current.primary.opacity(0.8)).lineLimit(1)
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
                                    .font(.app(18, .bold))
                                    .foregroundStyle(themeManager.current.primary)
                            }
                            Text("New Playlist")
                                .font(.app(15, .semibold))
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
                                .font(.app(32))
                                .foregroundStyle(.white.opacity(0.15))
                            Text("No playlists yet")
                                .font(themeManager.font(13))
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
                                                .font(.app(15, .semibold))
                                                .foregroundStyle(.white).lineLimit(1)
                                            Text("\(pl.tracks.count) tracks")
                                                .font(.app(11))
                                                .foregroundStyle(.white.opacity(0.4))
                                        }
                                        Spacer()
                                        if alreadyAdded {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.app(18))
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
                        .font(.app(14, .bold))
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
                    .font(.app(13, .semibold))
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
                        .font(.app(13, .semibold))
                        .foregroundStyle(playerVM.isPitchPreserved ? themeManager.current.primary : .white.opacity(0.4))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pitch lock")
                            .font(themeManager.font(13, .semibold))
                            .foregroundStyle(.white)
                        Text(playerVM.isPitchPreserved ? "Pitch preserved" : "Natural pitch shift")
                            .font(themeManager.font(11))
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
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                            onSelect(mode.speed)
                            currentSpeed = mode.speed
                        }
                    } label: {
                        VStack(spacing: 10) {
                            Image(systemName: mode.icon)
                                .font(.app(28, .regular))
                                .foregroundStyle(selected ? .black : .white)
                            Text(mode.label)
                                .font(themeManager.font(16, .semibold))
                                .foregroundStyle(selected ? .black : .white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 22)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(selected ? .white : Color.white.opacity(0.1))
                        )
                        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: selected)
                    }
                    .buttonStyle(ScaleButtonStyle(scale: 0.94))
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
        let progress = CGFloat((currentSpeed - speedMin) / (speedMax - speedMin))

        return VStack(spacing: 10) {
            GeometryReader { geo in
                let w  = geo.size.width
                let h  = geo.size.height
                let pad: CGFloat = 14
                let sx = pad
                let sy = h - pad * 0.4
                let ex = w - pad
                let ey = pad * 0.4

                let cx = sx + (ex - sx) * progress
                let cy = sy + (ey - sy) * progress

                ZStack {
                    Canvas { ctx, size in
                        // Background diagonal line
                        var bg = Path()
                        bg.move(to: CGPoint(x: sx, y: sy))
                        bg.addLine(to: CGPoint(x: ex, y: ey))
                        ctx.stroke(bg, with: .color(.white.opacity(0.18)),
                                   style: StrokeStyle(lineWidth: 3, lineCap: .round))

                        // Filled portion (start → current dot)
                        if progress > 0.01 {
                            var fg = Path()
                            fg.move(to: CGPoint(x: sx, y: sy))
                            fg.addLine(to: CGPoint(x: cx, y: cy))
                            ctx.stroke(fg, with: .color(.white),
                                       style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        }

                        // Snap markers at preset speeds
                        for snapSpeed: Float in [0.75, 1.0, 1.25] {
                            let p  = CGFloat((snapSpeed - speedMin) / (speedMax - speedMin))
                            let mx = sx + (ex - sx) * p
                            let my = sy + (ey - sy) * p
                            let r: CGFloat = 3.5
                            let rect = CGRect(x: mx - r, y: my - r, width: r * 2, height: r * 2)
                            let isPast = progress >= p
                            ctx.fill(Path(ellipseIn: rect),
                                     with: .color(isPast ? .white : .white.opacity(0.35)))
                        }
                    }

                    // Draggable position dot
                    Circle()
                        .fill(.white)
                        .frame(width: 20, height: 20)
                        .shadow(color: .black.opacity(0.45), radius: 6)
                        .position(x: cx, y: cy)
                        .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.75), value: progress)
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                    let pct   = max(0.0, min(1.0, (v.location.x - sx) / (ex - sx)))
                    var speed = Float(pct) * (speedMax - speedMin) + speedMin
                    for m in modes where abs(speed - m.speed) < 0.045 { speed = m.speed; break }
                    speed = (speed * 100).rounded() / 100
                    currentSpeed = speed
                    onSelect(speed)
                })
            }
            .frame(height: 80)

            Text(currentSpeed == 1.0 ? "1×" : "\(String(format: "%g", currentSpeed))×")
                .font(themeManager.font(14, .medium))
                .foregroundStyle(.white.opacity(0.55))
                .monospacedDigit()
        }
    }
}
