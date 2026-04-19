import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject var playerVM: PlayerViewModel

    @State private var showLyrics = false
    @State private var showQueue  = false

    private let speeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        VStack(spacing: 0) {
            // Artwork
            AsyncImage(url: URL(string: playerVM.currentTrack?.highResArtworkURL ?? "")) { img in
                img.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.1))
                    .overlay(Image(systemName: "music.note").font(.system(size: 56)).foregroundStyle(.white.opacity(0.3)))
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.5), radius: 24, x: 0, y: 12)
            .scaleEffect(playerVM.isPlaying ? 1.0 : 0.88)
            .animation(.spring(response: 0.45, dampingFraction: 0.65), value: playerVM.isPlaying)
            .padding(.horizontal, 32)
            .padding(.top, 24)

            // Title + artist + close
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(playerVM.currentTrack?.title ?? "Not Playing")
                        .font(.title2).fontWeight(.bold).foregroundStyle(.white)
                        .lineLimit(2)
                    Text(playerVM.currentTrack?.username ?? "")
                        .font(.callout).foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
                Spacer()
                Button { playerVM.showingNowPlaying = false } label: {
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.title2).foregroundStyle(.white.opacity(0.55))
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 20)

            // Progress slider
            VStack(spacing: 6) {
                Slider(
                    value: Binding(
                        get: { playerVM.currentTime },
                        set: { playerVM.seek(to: $0) }
                    ),
                    in: 0...(playerVM.duration > 0 ? playerVM.duration : 1)
                )
                .tint(.white)

                HStack {
                    Text(formatTime(playerVM.currentTime))
                    Spacer()
                    Text("-\(formatTime(max(0, playerVM.duration - playerVM.currentTime)))")
                }
                .font(.caption).foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 32)
            .padding(.top, 16)

            // Controls
            HStack {
                Spacer()
                Button { playerVM.skipPrevious() } label: {
                    Image(systemName: "backward.fill").font(.system(size: 28)).foregroundStyle(.white)
                }
                Spacer()
                Button { playerVM.togglePlayPause() } label: {
                    ZStack {
                        Circle().fill(.white).frame(width: 72, height: 72)
                        if playerVM.playerState == .loading {
                            ProgressView().tint(.black).scaleEffect(1.2)
                        } else {
                            Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(.black)
                                .offset(x: playerVM.isPlaying ? 0 : 2)
                        }
                    }
                }
                Spacer()
                Button { playerVM.skipNext() } label: {
                    Image(systemName: "forward.fill").font(.system(size: 28)).foregroundStyle(.white)
                }
                Spacer()
            }
            .padding(.top, 24)

            // Speed picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(speeds, id: \.self) { spd in
                        Button { playerVM.setSpeed(spd) } label: {
                            Text(speedLabel(spd))
                                .font(.caption).fontWeight(.semibold)
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .background(playerVM.playbackSpeed == spd ? Color.white : Color.white.opacity(0.15))
                                .foregroundStyle(playerVM.playbackSpeed == spd ? Color.black : Color.white)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 32)
            }
            .padding(.top, 20)

            // Lyrics + Queue
            HStack(spacing: 48) {
                Button { showLyrics = true } label: {
                    VStack(spacing: 5) {
                        Image(systemName: "quote.bubble").font(.title2)
                        Text("Lyrics").font(.caption2)
                    }.foregroundStyle(.white.opacity(0.7))
                }
                Button { showQueue = true } label: {
                    VStack(spacing: 5) {
                        Image(systemName: "list.bullet").font(.title2)
                        Text("Queue").font(.caption2)
                    }.foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(.top, 20)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(.dark)
        .presentationBackground {
            ZStack {
                if let urlStr = playerVM.currentTrack?.highResArtworkURL,
                   let url = URL(string: urlStr) {
                    AsyncImage(url: url) { img in
                        img.resizable().aspectRatio(contentMode: .fill)
                            .scaleEffect(1.5).blur(radius: 60)
                    } placeholder: { Color.black }
                } else {
                    Color.black
                }
                Color.black.opacity(0.65)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showLyrics) {
            if let t = playerVM.currentTrack { LyricsView(track: t) }
        }
        .sheet(isPresented: $showQueue) {
            QueueView().environmentObject(playerVM)
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
