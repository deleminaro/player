import SwiftUI

struct HomeView: View {
    @EnvironmentObject var playerVM:        PlayerViewModel
    @EnvironmentObject var themeManager:    ThemeManager
    @EnvironmentObject var firebaseManager: FirebaseManager
    @StateObject private var wave = WaveService.shared
    @State private var showArchive = false

    private var bg:     Color { themeManager.current.background }
    private var card:   Color { themeManager.current.card }
    private var accent: Color { themeManager.current.primary }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default:      return "Good night"
        }
    }

    private var firstName: String {
        let name = firebaseManager.currentUser?.displayName ?? ""
        return name.isEmpty ? "Listener" : (name.components(separatedBy: " ").first ?? name)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        greetingHeader
                            .padding(.horizontal, 20)
                            .padding(.top, 4)

                        waveCard
                            .padding(.horizontal, 20)

                        quickRow
                            .padding(.horizontal, 20)

                        if !playerVM.recentlyPlayed.isEmpty {
                            recentSection
                        } else {
                            emptyHint.padding(.horizontal, 20)
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
                    Text("POSTOR")
                        .font(.app(13, .black))
                        .kerning(2.5)
                        .foregroundStyle(accent)
                        .fixedSize()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    avatarView
                }
            }
        }
        .sheet(isPresented: $showArchive) {
            RecentlyPlayedView()
                .environmentObject(playerVM)
                .environmentObject(themeManager)
        }
    }

// MARK: - Greeting

    private var greetingHeader: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(greeting)
                .font(themeManager.font(13))
                .foregroundStyle(.white.opacity(0.4))
            Text(firstName)
                .font(themeManager.font(30, .black))
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        if let img = firebaseManager.currentUser?.avatarImage {
            Image(uiImage: img)
                .resizable().scaledToFill()
                .frame(width: 30, height: 30)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(accent.opacity(0.15))
                .frame(width: 30, height: 30)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.app(13))
                        .foregroundStyle(accent)
                )
        }
    }

    // MARK: - My Wave card

    private var waveCard: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 22).fill(card)
            LinearGradient(
                colors: [accent.opacity(0.55), accent.opacity(0.12), .clear],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 22))

            // Animated bars — full card
            AnimatedWaveBars(
                barCount:          48,
                maxHeightFraction: 0.90,
                baseOpacity:       0.055,
                accentColor:       .white
            )
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .allowsHitTesting(false)

            // POSTOR branding — top-left
            VStack(alignment: .leading, spacing: 2) {
                Text("POSTOR")
                    .font(.app(11, .black))
                    .kerning(2.5)
                    .foregroundStyle(.white.opacity(0.55))
                HStack(spacing: 5) {
                    Image(systemName: "waveform")
                        .font(.app(9, .bold))
                        .foregroundStyle(accent)
                    Text("MY WAVE")
                        .font(.app(9, .black))
                        .kerning(1.5)
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .allowsHitTesting(false)

            // Text + buttons
            VStack(alignment: .leading, spacing: 8) {
                Text(wave.waveTracks.isEmpty ? "Your personal radio" : "\(wave.waveTracks.count) tracks picked for you")
                    .font(themeManager.font(17, .bold))
                    .foregroundStyle(.white)
                if !wave.sourceArtists.isEmpty {
                    Text(wave.sourceArtists.prefix(3).joined(separator: " · "))
                        .font(themeManager.font(12))
                        .foregroundStyle(.white.opacity(0.4))
                        .lineLimit(1)
                }
                HStack(spacing: 10) {
                    Button {
                        guard !wave.waveTracks.isEmpty else { return }
                        playerVM.playFromList(wave.waveTracks, startingWith: wave.waveTracks[0])
                        playerVM.showingNowPlaying = true
                    } label: {
                        HStack(spacing: 6) {
                            if wave.isGenerating {
                                ProgressView().tint(themeManager.current.onPrimary).scaleEffect(0.7)
                            } else {
                                Image(systemName: "play.fill").font(.system(size: 11, weight: .bold))
                            }
                            Text(wave.isGenerating ? "Building…" : "Play Wave")
                                .font(themeManager.font(13, .semibold))
                        }
                        .foregroundStyle(themeManager.current.onPrimary)
                        .padding(.horizontal, 18).padding(.vertical, 9)
                        .background(accent, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle(scale: 0.93))
                    .disabled(wave.isGenerating || wave.waveTracks.isEmpty)

                    if !wave.waveTracks.isEmpty {
                        Button {
                            Task { await wave.generate(from: playerVM.recentlyPlayed) }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.app(13, .semibold))
                                .foregroundStyle(.white.opacity(0.5))
                                .frame(width: 36, height: 36)
                                .background(Color.white.opacity(0.08), in: Circle())
                        }
                        .buttonStyle(ScaleButtonStyle(scale: 0.93))
                        .disabled(wave.isGenerating)
                    }
                }
                .padding(.top, 2)
            }
            .padding(20)
        }
        .frame(minHeight: 140)
    }

    // MARK: - Quick access row

    private var quickRow: some View {
        HStack(spacing: 12) {
            quickCard(
                title: "Recent", icon: "clock.fill",
                count: playerVM.recentlyPlayed.count,
                artwork: playerVM.recentlyPlayed.first?.thumbnailArtworkURL
            ) {
                guard !playerVM.recentlyPlayed.isEmpty else { return }
                playerVM.playFromList(playerVM.recentlyPlayed, startingWith: playerVM.recentlyPlayed[0])
                playerVM.showingNowPlaying = true
            }
            quickCard(
                title: "Liked", icon: "heart.fill",
                count: playerVM.likedTracks.count,
                artwork: playerVM.likedTracks.first?.thumbnailArtworkURL
            ) {
                guard !playerVM.likedTracks.isEmpty else { return }
                playerVM.playFromList(playerVM.likedTracks, startingWith: playerVM.likedTracks[0])
                playerVM.showingNowPlaying = true
            }
        }
    }

    private func quickCard(title: String, icon: String, count: Int, artwork: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    if artwork != nil {
                        CachedAsyncImage(url: artwork) { img in
                            img.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            card
                        }
                        .frame(width: 46, height: 46)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(accent.opacity(0.15))
                            .frame(width: 46, height: 46)
                            .overlay(
                                Image(systemName: icon)
                                    .font(.app(16))
                                    .foregroundStyle(accent)
                            )
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(themeManager.font(14, .semibold)).foregroundStyle(.white)
                    Text("\(count) tracks").font(themeManager.font(11)).foregroundStyle(.white.opacity(0.4))
                }
                Spacer(minLength: 0)
                Image(systemName: "play.fill")
                    .font(.app(11, .bold))
                    .foregroundStyle(themeManager.current.onPrimary)
                    .frame(width: 32, height: 32)
                    .background(accent, in: Circle())
            }
            .padding(14)
            .background(card, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.95))
        .frame(maxWidth: .infinity)
    }

    // MARK: - Recently played

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("RECENTLY PLAYED")
                    .font(.app(10, .black)).kerning(2)
                    .foregroundStyle(.white.opacity(0.3))
                Spacer()
                Button { showArchive = true } label: {
                    Text("See all")
                        .font(themeManager.font(13, .semibold))
                        .foregroundStyle(accent)
                }
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(playerVM.recentlyPlayed.prefix(14)) { track in
                        recentCard(track)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func recentCard(_ track: Track) -> some View {
        Button {
            playerVM.play(track)
            playerVM.showingNowPlaying = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    CachedAsyncImage(url: track.highResArtworkURL ?? track.thumbnailArtworkURL) { img in
                        img.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        card.overlay(
                            Image(systemName: "music.note")
                                .font(.app(22))
                                .foregroundStyle(.white.opacity(0.1))
                        )
                    }
                    .frame(width: 132, height: 132)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    ZStack {
                        Circle().fill(.black.opacity(0.5)).frame(width: 28, height: 28)
                        Image(systemName: playerVM.currentTrack?.id == track.id && playerVM.isPlaying ? "pause.fill" : "play.fill")
                            .font(.app(9, .bold))
                            .foregroundStyle(.white)
                            .offset(x: playerVM.currentTrack?.id == track.id && playerVM.isPlaying ? 0 : 1)
                    }
                    .padding(8)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(themeManager.font(12, .semibold))
                        .foregroundStyle(playerVM.currentTrack?.id == track.id ? accent : .white)
                        .lineLimit(1).frame(width: 132, alignment: .leading)
                    Text(track.username)
                        .font(themeManager.font(11))
                        .foregroundStyle(.white.opacity(0.4))
                        .lineLimit(1).frame(width: 132, alignment: .leading)
                }
            }
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.95))
    }

    private var emptyHint: some View {
        VStack(spacing: 14) {
            Image(systemName: "headphones")
                .font(.app(44))
                .foregroundStyle(accent.opacity(0.25))
                .padding(.top, 32)
            Text("Nothing here yet")
                .font(themeManager.font(17, .semibold))
                .foregroundStyle(.white.opacity(0.4))
            Text("Search for tracks to build\nyour listening history.")
                .font(themeManager.font(13))
                .foregroundStyle(.white.opacity(0.25))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
