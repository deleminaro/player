import SwiftUI

struct WaveView: View {
    @EnvironmentObject var playerVM:    PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var wave = WaveService.shared

    private var bg:     Color { themeManager.current.background }
    private var card:   Color { themeManager.current.card }
    private var accent: Color { themeManager.current.primary }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    waveHeader
                    if wave.isGenerating {
                        generatingView
                    } else if wave.waveTracks.isEmpty {
                        emptyState
                    } else {
                        trackList
                    }
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
                    Text("MY WAVE")
                        .font(.system(size: 12, weight: .black))
                        .kerning(2.5)
                        .foregroundStyle(.white)
                }
                if !wave.waveTracks.isEmpty && !wave.isGenerating {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task { await wave.generate(from: playerVM.recentlyPlayed) }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                    }
                }
            }
        }
        .task {
            if wave.waveTracks.isEmpty && !wave.isGenerating {
                await wave.generate(from: playerVM.recentlyPlayed)
            }
        }
    }

    // MARK: - Header

    private var waveHeader: some View {
        VStack(spacing: 18) {
            WaveHeaderBars()
                .frame(height: 72)
                .padding(.top, 20)

            if !wave.sourceArtists.isEmpty {
                VStack(spacing: 5) {
                    Text("BASED ON YOUR LISTENING")
                        .font(.system(size: 9, weight: .black))
                        .kerning(1.5)
                        .foregroundStyle(.white.opacity(0.3))
                    Text(wave.sourceArtists.joined(separator: "  ·  "))
                        .font(themeManager.font(13, .semibold))
                        .foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 32)
                }
            }

            if !wave.waveTracks.isEmpty {
                HStack(spacing: 12) {
                    Button {
                        playerVM.playFromList(wave.waveTracks, startingWith: wave.waveTracks[0])
                        playerVM.showingNowPlaying = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text("Play Wave")
                                .font(themeManager.font(15, .bold))
                        }
                        .foregroundStyle(themeManager.current.onPrimary)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 13)
                        .background(accent, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle(scale: 0.93))

                    Button {
                        let shuffled = wave.waveTracks.shuffled()
                        playerVM.playFromList(shuffled, startingWith: shuffled[0])
                        playerVM.showingNowPlaying = true
                    } label: {
                        Image(systemName: "shuffle")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.55))
                            .frame(width: 46, height: 46)
                            .background(Color.white.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(ScaleButtonStyle(scale: 0.93))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 28)
    }

    // MARK: - Track list

    private var trackList: some View {
        LazyVStack(spacing: 0) {
            Divider().background(Color.white.opacity(0.06))
            ForEach(Array(wave.waveTracks.enumerated()), id: \.element.id) { idx, track in
                TrackRowView(
                    track: track,
                    isLiked: playerVM.isLiked(track),
                    onToggleLike: { playerVM.toggleLike(track) }
                )
                .onTapGesture {
                    playerVM.playFromList(wave.waveTracks, startingWith: track)
                    playerVM.showingNowPlaying = true
                }
                Divider()
                    .background(Color.white.opacity(0.06))
                    .padding(.leading, 76)
            }
        }
    }

    // MARK: - States

    private var generatingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(accent)
                .scaleEffect(1.3)
                .padding(.top, 60)
            Text("Building your wave…")
                .font(themeManager.font(14, .semibold))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform")
                .font(.system(size: 48))
                .foregroundStyle(accent.opacity(0.3))
                .padding(.top, 60)
            VStack(spacing: 8) {
                Text("No Wave Yet")
                    .font(themeManager.font(20, .bold))
                    .foregroundStyle(.white.opacity(0.7))
                Text("Play some songs and we'll build\na personalised radio for you.")
                    .font(themeManager.font(14))
                    .foregroundStyle(.white.opacity(0.3))
                    .multilineTextAlignment(.center)
            }
            Button {
                Task { await wave.generate(from: playerVM.recentlyPlayed) }
            } label: {
                Text("Generate Wave")
                    .font(themeManager.font(15, .semibold))
                    .foregroundStyle(themeManager.current.onPrimary)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 13)
                    .background(accent, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.93))
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
    }
}

// MARK: - Animated wave bars

struct WaveHeaderBars: View {
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<36, id: \.self) { i in
                    let h = barHeight(t: t, i: i)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor(i: i))
                        .frame(width: 3, height: h)
                }
            }
        }
    }

    private func barHeight(t: Double, i: Int) -> CGFloat {
        let w1 = sin(t * 2.2 + Double(i) * 0.38)
        let w2 = sin(t * 3.5 + Double(i) * 0.55)
        let w3 = sin(Double(i) * 0.7)
        let v  = (w1 + w2 + w3) / 3.0
        return CGFloat(10 + (v + 1) / 2.0 * 62)
    }

    private func barColor(i: Int) -> Color {
        let phase   = Double(i) / 36.0
        let opacity = 0.2 + phase * 0.6
        return themeManager.current.primary.opacity(opacity)
    }
}
