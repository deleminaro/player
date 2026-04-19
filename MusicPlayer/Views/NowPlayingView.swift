import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject var playerVM: PlayerViewModel

    @State private var showLyrics = false
    @State private var showQueue  = false

    private let speeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                background

                VStack(spacing: 0) {
                    Spacer().frame(height: 16)

                    // Artwork
                    artworkView(size: min(geo.size.width - 64, 300))
                        .padding(.top, 12)

                    // Title + artist + dismiss button
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(playerVM.currentTrack?.title ?? "Not Playing")
                                .font(.title2).fontWeight(.bold)
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(playerVM.currentTrack?.username ?? "")
                                .font(.callout)
                                .foregroundStyle(.white.opacity(0.65))
                                .lineLimit(1)
                        }
                        Spacer(minLength: 12)
                        Button { playerVM.showingNowPlaying = false } label: {
                            Image(systemName: "chevron.down.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .padding(.top, 20)

                    // Progress
                    progressSection
                        .padding(.top, 18)

                    // Controls
                    controlButtons
                        .padding(.top, 22)

                    // Speed
                    speedPicker
                        .padding(.top, 22)

                    // Action row
                    actionRow
                        .padding(.top, 22)

                    Spacer(minLength: 16)
                }
                .padding(.horizontal, 28)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showLyrics) {
            if let t = playerVM.currentTrack { LyricsView(track: t) }
        }
        .sheet(isPresented: $showQueue) {
            QueueView().environmentObject(playerVM)
        }
    }

    // MARK: - Sub-views

    private var background: some View {
        ZStack {
            if let urlStr = playerVM.currentTrack?.highResArtworkURL,
               let url = URL(string: urlStr) {
                AsyncImage(url: url) { img in
                    img.resizable()
                        .aspectRatio(contentMode: .fill)
                        .scaleEffect(1.5)
                        .blur(radius: 60)
                } placeholder: {
                    Color.black
                }
            } else {
                LinearGradient(
                    colors: [Color(white: 0.12), Color(white: 0.06)],
                    startPoint: .top, endPoint: .bottom
                )
            }
            Color.black.opacity(0.62)
        }
        .ignoresSafeArea()
    }

    private func artworkView(size: CGFloat) -> some View {
        AsyncImage(url: URL(string: playerVM.currentTrack?.highResArtworkURL ?? "")) { img in
            img.resizable().aspectRatio(contentMode: .fill)
        } placeholder: {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.12))
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 56))
                        .foregroundStyle(.white.opacity(0.35))
                )
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.6), radius: 28, x: 0, y: 14)
        .scaleEffect(playerVM.isPlaying ? 1.0 : 0.90)
        .animation(.spring(response: 0.45, dampingFraction: 0.65), value: playerVM.isPlaying)
    }

    private var progressSection: some View {
        VStack(spacing: 8) {
            Slider(
                value: Binding(
                    get: { playerVM.currentTime },
                    set: { playerVM.seek(to: $0) }
                ),
                in: 0...(playerVM.duration > 0 ? playerVM.duration : 1)
            )
            .tint(.white)
            .frame(maxWidth: .infinity)

            HStack {
                Text(formatTime(playerVM.currentTime))
                Spacer()
                Text("-\(formatTime(max(0, playerVM.duration - playerVM.currentTime)))")
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.55))
        }
    }

    private var controlButtons: some View {
        HStack(spacing: 0) {
            Spacer()
            Button { playerVM.skipPrevious() } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
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
                Image(systemName: "forward.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
            }
            Spacer()
        }
    }

    private var speedPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Speed")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))

            HStack(spacing: 8) {
                ForEach(speeds, id: \.self) { spd in
                    Button { playerVM.setSpeed(spd) } label: {
                        Text(speedLabel(spd))
                            .font(.caption).fontWeight(.semibold)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(playerVM.playbackSpeed == spd ? Color.white : Color.white.opacity(0.15))
                            .foregroundStyle(playerVM.playbackSpeed == spd ? Color.black : Color.white)
                            .clipShape(Capsule())
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var actionRow: some View {
        HStack(spacing: 48) {
            iconButton(icon: "quote.bubble", label: "Lyrics") { showLyrics = true }
            iconButton(icon: "list.bullet",  label: "Queue")  { showQueue  = true }
        }
        .frame(maxWidth: .infinity)
    }

    private func iconButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.title2)
                Text(label).font(.caption2)
            }
            .foregroundStyle(.white.opacity(0.75))
        }
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        let t = Int(max(0, seconds))
        return String(format: "%d:%02d", t / 60, t % 60)
    }

    private func speedLabel(_ s: Float) -> String {
        s == 1.0 ? "1×" : "\(String(format: "%g", s))×"
    }
}
