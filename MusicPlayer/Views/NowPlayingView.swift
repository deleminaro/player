import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @State private var showLyrics = false
    @State private var showQueue  = false
    @State private var showEQ     = false

    private let speeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
    private let bg      = Color(red: 0.075, green: 0.075, blue: 0.075)
    private let primary = Color(red: 0.753, green: 0.757, blue: 1.0)
    private let onPrimary = Color(red: 0.063, green: 0, blue: 0.663)

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            // Subtle artwork ambient glow
            if let urlStr = playerVM.currentTrack?.highResArtworkURL,
               let url = URL(string: urlStr) {
                AsyncImage(url: url) { img in
                    img.resizable().aspectRatio(contentMode: .fill)
                        .scaleEffect(2).blur(radius: 80).opacity(0.12)
                } placeholder: { Color.clear }
                .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                // Artwork
                AsyncImage(url: URL(string: playerVM.currentTrack?.highResArtworkURL ?? "")) { img in
                    img.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 32)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 56))
                                .foregroundStyle(.white.opacity(0.15))
                        )
                }
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 32))
                .shadow(color: .black.opacity(0.75), radius: 40, x: 0, y: 20)
                .scaleEffect(playerVM.isPlaying ? 1.0 : 0.86)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: playerVM.isPlaying)
                .padding(.horizontal, 28)
                .padding(.top, 20)

                // Track info + close button
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text((playerVM.currentTrack?.title ?? "Not Playing").uppercased())
                            .font(.system(size: 17, weight: .black))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Text((playerVM.currentTrack?.username ?? "").uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(primary)
                            .kerning(2)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button { playerVM.showingNowPlaying = false } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(10)
                            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 22)

                // Progress
                VStack(spacing: 7) {
                    Slider(
                        value: Binding(
                            get: { playerVM.currentTime },
                            set: { playerVM.seek(to: $0) }
                        ),
                        in: 0...(playerVM.duration > 0 ? playerVM.duration : 1)
                    )
                    .tint(primary)

                    HStack {
                        Text(formatTime(playerVM.currentTime))
                        Spacer()
                        Text("-\(formatTime(max(0, playerVM.duration - playerVM.currentTime)))")
                    }
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.35))
                }
                .padding(.horizontal, 28)
                .padding(.top, 18)

                // Playback controls
                HStack {
                    Spacer()
                    Button { playerVM.skipPrevious() } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Button { playerVM.togglePlayPause() } label: {
                        ZStack {
                            Circle().fill(primary).frame(width: 70, height: 70)
                            if playerVM.playerState == .loading {
                                ProgressView().tint(onPrimary).scaleEffect(1.1)
                            } else {
                                Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundStyle(onPrimary)
                                    .offset(x: playerVM.isPlaying ? 0 : 2)
                            }
                        }
                    }
                    Spacer()
                    Button { playerVM.skipNext() } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                }
                .padding(.top, 22)

                // Speed + Lyrics + Queue row
                HStack(spacing: 0) {
                    Menu {
                        ForEach(speeds, id: \.self) { spd in
                            Button(speedLabel(spd)) { playerVM.setSpeed(spd) }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "gauge.with.dots.needle.67percent")
                                .font(.system(size: 12, weight: .bold))
                            Text(speedLabel(playerVM.playbackSpeed))
                                .font(.system(size: 12, weight: .black))
                        }
                        .foregroundStyle(primary)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(primary.opacity(0.12), in: Capsule())
                    }

                    Spacer()

                    Button { showLyrics = true } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "quote.bubble").font(.system(size: 20))
                            Text("LYRICS").font(.system(size: 8, weight: .black)).kerning(1)
                        }
                        .foregroundStyle(.white.opacity(0.45))
                    }

                    Spacer().frame(width: 28)

                    Button { showQueue = true } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "list.bullet").font(.system(size: 20))
                            Text("QUEUE").font(.system(size: 8, weight: .black)).kerning(1)
                        }
                        .foregroundStyle(.white.opacity(0.45))
                    }

                    Spacer().frame(width: 28)

                    Button { showEQ = true } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "slider.vertical.3").font(.system(size: 20))
                            Text("EQ").font(.system(size: 8, weight: .black)).kerning(1)
                        }
                        .foregroundStyle(.white.opacity(0.45))
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 22)

                Spacer()
            }
        }
        .preferredColorScheme(.dark)
        .presentationBackground(bg)
        .sheet(isPresented: $showLyrics) {
            if let t = playerVM.currentTrack { LyricsView(track: t) }
        }
        .sheet(isPresented: $showQueue) {
            QueueView().environmentObject(playerVM)
        }
        .sheet(isPresented: $showEQ) {
            EqualizerView().environmentObject(playerVM)
        }
    }

    private func formatTime(_ s: Double) -> String {
        guard s.isFinite else { return "0:00" }
        let t = Int(max(0, s))
        return String(format: "%d:%02d", t / 60, t % 60)
    }

    private func speedLabel(_ s: Float) -> String {
        s == 1.0 ? "1×" : "\(String(format: "%g", s))×"
    }
}
