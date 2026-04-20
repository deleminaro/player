import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @State private var showLyrics = false
    @State private var showQueue  = false
    @State private var showEQ     = false
    @State private var showSpeed  = false

    private let speeds: [Float] = [0.5, 0.75, 1.0, 1.15, 1.25, 1.5, 2.0]
    private let primary   = Color(red: 0.753, green: 0.757, blue: 1.0)
    private let onPrimary = Color(red: 0.063, green: 0, blue: 0.663)
    private let bg        = Color(red: 0.075, green: 0.075, blue: 0.075)

    var body: some View {
        ZStack {
            // Full-bleed artwork background
            GeometryReader { geo in
                ZStack {
                    bg
                    if let url = URL(string: playerVM.currentTrack?.highResArtworkURL ?? "") {
                        AsyncImage(url: url) { img in
                            img.resizable().aspectRatio(contentMode: .fill)
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
                        } placeholder: { Color.clear }
                    }
                    // Gradient: lighter on top so artwork shows, darker on bottom for readability
                    LinearGradient(
                        colors: [
                            .black.opacity(0.15),
                            .black.opacity(0.35),
                            .black.opacity(0.65),
                            .black.opacity(0.88)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                // Top bar
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                Spacer()

                // Content pinned to bottom
                VStack(alignment: .leading, spacing: 0) {
                    trackInfo
                    waveformProgress
                        .padding(.top, 20)
                    controlsRow
                        .padding(.top, 18)
                    actionRow
                        .padding(.top, 20)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 44)
            }
        }
        .preferredColorScheme(.dark)
        .presentationBackground(.black)
        .sheet(isPresented: $showLyrics) {
            if let t = playerVM.currentTrack { LyricsView(track: t) }
        }
        .sheet(isPresented: $showQueue) {
            QueueView().environmentObject(playerVM)
        }
        .sheet(isPresented: $showEQ) {
            EqualizerView().environmentObject(playerVM)
        }
        .sheet(isPresented: $showSpeed) {
            SpeedPickerSheet(currentSpeed: $playerVM.playbackSpeed) { spd in
                playerVM.setSpeed(spd)
            }
            .presentationDetents([.height(320)])
            .presentationBackground(.ultraThinMaterial)
            .presentationCornerRadius(28)
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
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text((playerVM.currentTrack?.username ?? "").uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(primary)
                    .kerning(1.5)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                if let t = playerVM.currentTrack { playerVM.toggleLike(t) }
            } label: {
                Image(systemName: playerVM.currentTrack.map { playerVM.isLiked($0) } == true
                      ? "heart.fill" : "heart")
                    .font(.system(size: 22))
                    .foregroundStyle(playerVM.currentTrack.map { playerVM.isLiked($0) } == true
                                     ? .pink : .white.opacity(0.5))
            }
        }
    }

    // MARK: - Waveform-style progress

    private var waveformProgress: some View {
        let progress = playerVM.duration > 0 ? playerVM.currentTime / playerVM.duration : 0
        let bars = waveformHeights(for: playerVM.currentTrack?.id ?? 0)

        return VStack(spacing: 6) {
            GeometryReader { geo in
                HStack(alignment: .center, spacing: geo.size.width / CGFloat(bars.count) * 0.25) {
                    ForEach(bars.indices, id: \.self) { i in
                        let filled = Double(i) / Double(bars.count) < progress
                        Capsule()
                            .fill(filled ? primary : Color.white.opacity(0.22))
                            .frame(
                                width: max(2, geo.size.width / CGFloat(bars.count) * 0.72),
                                height: bars[i] * geo.size.height
                            )
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                    let pct = max(0, min(1, v.location.x / geo.size.width))
                    playerVM.seek(to: pct * playerVM.duration)
                })
            }
            .frame(height: 48)

            HStack {
                Text(formatTime(playerVM.currentTime))
                Spacer()
                Text(formatTime(max(0, playerVM.duration - playerVM.currentTime)))
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white.opacity(0.45))
            .monospacedDigit()
        }
    }

    // MARK: - Controls

    private var controlsRow: some View {
        HStack {
            // Shuffle
            Button { playerVM.isShuffling.toggle() } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(playerVM.isShuffling ? primary : .white.opacity(0.4))
            }

            Spacer()

            // Previous
            Button { playerVM.skipPrevious() } label: {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Spacer()

            // Play / Pause
            Button { playerVM.togglePlayPause() } label: {
                ZStack {
                    Circle().fill(.white).frame(width: 64, height: 64)
                    if playerVM.playerState == .loading {
                        ProgressView().tint(.black).scaleEffect(1.1)
                    } else {
                        Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.black)
                            .offset(x: playerVM.isPlaying ? 0 : 2)
                    }
                }
            }

            Spacer()

            // Next
            Button { playerVM.skipNext() } label: {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Spacer()

            // Repeat
            Button { playerVM.isRepeating.toggle() } label: {
                Image(systemName: playerVM.isRepeating ? "repeat.1" : "repeat")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(playerVM.isRepeating ? primary : .white.opacity(0.4))
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

            // Right: speed, queue
            HStack(spacing: 12) {
                Button { showSpeed = true } label: {
                    Text(speedLabel(playerVM.playbackSpeed))
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(.white.opacity(0.8))
                        .monospacedDigit()
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
                                .background(primary, in: Circle())
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

    private func speedLabel(_ s: Float) -> String {
        s == 1.0 ? "1×" : "\(String(format: "%g", s))×"
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

// MARK: - Speed picker sheet

struct SpeedPickerSheet: View {
    @Binding var currentSpeed: Float
    let onSelect: (Float) -> Void
    @Environment(\.dismiss) var dismiss

    private let primary = Color(red: 0.753, green: 0.757, blue: 1.0)

    private struct SpeedMode {
        let label: String
        let icon: String
        let speed: Float
    }
    private let modes: [SpeedMode] = [
        SpeedMode(label: "Slowed",   icon: "person.wave.2",  speed: 0.8),
        SpeedMode(label: "Default",  icon: "play.circle",    speed: 1.0),
        SpeedMode(label: "Speedup",  icon: "speedometer",    speed: 1.5),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color.white.opacity(0.25))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)

            // Pitch note
            HStack(spacing: 6) {
                Image(systemName: "waveform")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(primary)
                Text("PITCH IS PRESERVED AT ALL SPEEDS")
                    .font(.system(size: 10, weight: .black)).kerning(1.5)
                    .foregroundStyle(primary)
            }
            .padding(.horizontal, 20).padding(.vertical, 8)
            .background(primary.opacity(0.12), in: Capsule())
            .padding(.bottom, 24)

            // Three mode buttons
            HStack(spacing: 12) {
                ForEach(modes, id: \.speed) { mode in
                    let selected = abs(currentSpeed - mode.speed) < 0.01
                    Button {
                        onSelect(mode.speed)
                        currentSpeed = mode.speed
                        dismiss()
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

            Spacer()
        }
        .preferredColorScheme(.dark)
    }
}
