import SwiftUI

// MARK: - Mood preset model

private struct WaveMood: Identifiable {
    let id    = UUID()
    let label: String
    let emoji: String
    let query: String
    let color: Color
}

private let waveMoods: [WaveMood] = [
    WaveMood(label: "Gym",     emoji: "🏋️", query: "gym workout motivation energy pump",    color: Color(red: 1.0, green: 0.25, blue: 0.15)),
    WaveMood(label: "Chill",   emoji: "😌", query: "chill lofi relax calm vibes",            color: Color(red: 0.25, green: 0.50, blue: 1.0)),
    WaveMood(label: "Party",   emoji: "🎉", query: "party dance club banger DJ",             color: Color(red: 1.0, green: 0.45, blue: 0.0)),
    WaveMood(label: "Focus",   emoji: "🎯", query: "focus study deep work ambient",          color: Color(red: 0.55, green: 0.28, blue: 1.0)),
    WaveMood(label: "Morning", emoji: "🌅", query: "morning energy upbeat fresh start",      color: Color(red: 1.0, green: 0.78, blue: 0.10)),
    WaveMood(label: "Sleep",   emoji: "🌙", query: "sleep calm ambient peaceful instrumental", color: Color(red: 0.22, green: 0.28, blue: 0.80)),
    WaveMood(label: "Hype",    emoji: "🔥", query: "hype trap rap fire hard 2024",           color: Color(red: 1.0, green: 0.20, blue: 0.20)),
    WaveMood(label: "RnB",     emoji: "🎵", query: "rnb soul smooth groove",                 color: Color(red: 0.80, green: 0.28, blue: 0.65)),
    WaveMood(label: "Rock",    emoji: "🎸", query: "rock alternative indie guitar",          color: Color(red: 0.72, green: 0.48, blue: 0.18)),
    WaveMood(label: "Jazz",    emoji: "🎷", query: "jazz lofi instrumental smooth cafe",     color: Color(red: 0.15, green: 0.65, blue: 0.55)),
]

// MARK: - Wave mode

private enum WaveMode { case forYou, discover }

// MARK: - Main View

struct WaveView: View {
    @EnvironmentObject var playerVM:    PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var wave = WaveService.shared

    @State private var mode:        WaveMode = .forYou
    @State private var searchText:  String   = ""
    @State private var isSearching: Bool     = false
    @FocusState private var searchFocused: Bool

    private var bg:     Color { themeManager.current.background }
    private var card:   Color { themeManager.current.card }
    private var accent: Color { themeManager.current.primary }

    private var activeTracks: [Track]  { mode == .forYou ? wave.waveTracks : wave.discoverTracks }
    private var isLoading:    Bool     { mode == .forYou ? wave.isGenerating : wave.isDiscovering }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    modeSwitcher.padding(.top, 16).padding(.horizontal, 20)
                    waveHeader
                    if isLoading {
                        generatingView
                    } else if mode == .discover {
                        discoverSection
                        if !wave.discoverTracks.isEmpty {
                            trackList(wave.discoverTracks)
                        }
                    } else if wave.waveTracks.isEmpty {
                        forYouEmpty
                    } else {
                        trackList(wave.waveTracks)
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
                if !activeTracks.isEmpty && !isLoading {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            if mode == .forYou {
                                Task { await wave.generate(from: playerVM.recentlyPlayed) }
                            } else if let label = wave.seedLabel {
                                let mood = waveMoods.first { $0.label == label }
                                let query = mood?.query ?? label
                                Task { await wave.generateFromSeed(query: query, label: label) }
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                    }
                }
            }
            .onTapGesture { searchFocused = false }
        }
        .task {
            if wave.waveTracks.isEmpty && !wave.isGenerating {
                await wave.generate(from: playerVM.recentlyPlayed)
            }
        }
    }

    // MARK: - Mode switcher

    private var modeSwitcher: some View {
        HStack(spacing: 8) {
            modeTab("For You",  active: mode == .forYou)  { withAnimation(.spring(response: 0.3)) { mode = .forYou } }
            modeTab("Discover", active: mode == .discover) { withAnimation(.spring(response: 0.3)) { mode = .discover } }
            Spacer()
        }
    }

    private func modeTab(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(themeManager.font(13, active ? .bold : .semibold))
                .foregroundStyle(active ? .white : .white.opacity(0.38))
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(active ? accent.opacity(0.18) : .clear, in: Capsule())
                .overlay(Capsule().stroke(active ? accent.opacity(0.5) : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Shared header (play/shuffle buttons)

    private var waveHeader: some View {
        VStack(spacing: 18) {
            WaveHeaderBars()
                .frame(height: 60)
                .padding(.top, 18)

            if mode == .forYou && !wave.sourceArtists.isEmpty {
                VStack(spacing: 5) {
                    Text("BASED ON YOUR LISTENING")
                        .font(.system(size: 9, weight: .black)).kerning(1.5)
                        .foregroundStyle(.white.opacity(0.3))
                    Text(wave.sourceArtists.joined(separator: "  ·  "))
                        .font(themeManager.font(13, .semibold))
                        .foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.center).lineLimit(2)
                        .padding(.horizontal, 32)
                }
            }

            if mode == .discover, let label = wave.seedLabel, !wave.discoverTracks.isEmpty {
                VStack(spacing: 5) {
                    Text("WAVE FOR")
                        .font(.system(size: 9, weight: .black)).kerning(1.5)
                        .foregroundStyle(.white.opacity(0.3))
                    Text(label)
                        .font(themeManager.font(15, .bold))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }

            if !activeTracks.isEmpty {
                HStack(spacing: 12) {
                    Button {
                        playerVM.playFromList(activeTracks, startingWith: activeTracks[0])
                        playerVM.showingNowPlaying = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill").font(.system(size: 13, weight: .bold))
                            Text("Play Wave").font(themeManager.font(15, .bold))
                        }
                        .foregroundStyle(themeManager.current.onPrimary)
                        .padding(.horizontal, 28).padding(.vertical, 13)
                        .background(accent, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle(scale: 0.93))

                    Button {
                        let shuffled = activeTracks.shuffled()
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
        .padding(.bottom, 20)
    }

    // MARK: - Discover section

    private var discoverSection: some View {
        VStack(alignment: .leading, spacing: 22) {
            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.4))
                    .font(.system(size: 14))
                TextField("Artist, song, or vibe…", text: $searchText)
                    .foregroundStyle(.white)
                    .tint(accent)
                    .focused($searchFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        let q = searchText.trimmingCharacters(in: .whitespaces)
                        guard !q.isEmpty else { return }
                        searchFocused = false
                        Task { await wave.generateFromSeed(query: q, label: q) }
                    }
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(card, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 20)

            // Moods grid
            VStack(alignment: .leading, spacing: 10) {
                Text("MOODS & ACTIVITIES")
                    .font(.system(size: 10, weight: .black)).kerning(2)
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.horizontal, 20)

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(waveMoods) { mood in
                        moodCard(mood)
                    }
                }
                .padding(.horizontal, 20)
            }

            if !wave.discoverTracks.isEmpty {
                Divider()
                    .background(Color.white.opacity(0.06))
                    .padding(.top, 8)
            }
        }
        .padding(.top, 4)
    }

    private func moodCard(_ mood: WaveMood) -> some View {
        let isActive = wave.seedLabel == mood.label && !wave.discoverTracks.isEmpty
        return Button {
            searchText    = ""
            searchFocused = false
            Task { await wave.generateFromSeed(query: mood.query, label: mood.label) }
        } label: {
            HStack(spacing: 10) {
                Text(mood.emoji)
                    .font(.system(size: 22))
                    .frame(width: 36, height: 36)
                    .background(mood.color.opacity(0.18), in: RoundedRectangle(cornerRadius: 10))
                Text(mood.label)
                    .font(themeManager.font(14, .semibold))
                    .foregroundStyle(.white)
                Spacer()
                if isActive {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(mood.color)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(
                isActive
                    ? mood.color.opacity(0.15)
                    : card,
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isActive ? mood.color.opacity(0.5) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.95))
        .disabled(wave.isDiscovering)
    }

    // MARK: - Track list

    private func trackList(_ tracks: [Track]) -> some View {
        LazyVStack(spacing: 0) {
            Divider().background(Color.white.opacity(0.06))
            ForEach(Array(tracks.enumerated()), id: \.offset) { _, track in
                TrackRowView(
                    track: track,
                    isLiked: playerVM.isLiked(track),
                    onToggleLike: { playerVM.toggleLike(track) }
                )
                .onTapGesture {
                    playerVM.playFromList(tracks, startingWith: track)
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
            ProgressView().tint(accent).scaleEffect(1.3).padding(.top, 60)
            Text(mode == .forYou ? "Building your wave…" : "Finding your vibe…")
                .font(themeManager.font(14, .semibold))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 32)
    }

    private var forYouEmpty: some View {
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
                    .padding(.horizontal, 30).padding(.vertical, 13)
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

struct AnimatedWaveBars: View {
    var barCount:          Int     = 36
    var maxHeightFraction: CGFloat = 0.50
    var baseOpacity:       Double  = 0.07
    var accentColor:       Color

    @Environment(\.scenePhase) private var phase

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20)) { tl in
            let t = phase == .active ? tl.date.timeIntervalSinceReferenceDate : 0
                Canvas { ctx, size in
                    let bw   = size.width / CGFloat(barCount)
                    let maxH = size.height * maxHeightFraction
                    for i in 0..<barCount {
                        let fi  = Double(i)
                        let v   = (sin(t * 2.2 + fi * 0.38)
                                 + sin(t * 3.5 + fi * 0.55)
                                 + sin(fi * 0.7)) / 3.0
                        let h   = maxH * CGFloat(0.10 + (v + 1) / 2.0 * 0.90)
                        let opc = baseOpacity + fi / Double(barCount) * baseOpacity
                        let rect = CGRect(x: CGFloat(i) * bw,
                                          y: size.height - h,
                                          width: max(bw - 2, 1),
                                          height: h)
                        ctx.fill(Path(roundedRect: rect, cornerRadius: 2),
                                 with: .color(accentColor.opacity(opc)))
                    }
                }
            }
    }
}

struct WaveHeaderBars: View {
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        AnimatedWaveBars(
            barCount:          36,
            maxHeightFraction: 1.0,
            baseOpacity:       0.20,
            accentColor:       themeManager.current.primary
        )
    }
}
