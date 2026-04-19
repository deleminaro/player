import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @Environment(\.dismiss)  var dismiss

    @State private var showLyrics = false
    @State private var showQueue  = false

    private let speeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                dragHandle.padding(.top, 14)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 26) {
                        artworkView
                        trackInfo
                        progressSection
                        controlButtons
                        speedPicker
                        actionRow
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 40)
                }
            }
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
            AsyncImage(url: URL(string: playerVM.currentTrack?.highResArtworkURL ?? "")) { img in
                img.resizable().aspectRatio(contentMode: .fill)
                    .blur(radius: 70).scaleEffect(1.4)
            } placeholder: {
                LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            Color.black.opacity(0.58)
        }
        .ignoresSafeArea()
    }

    private var dragHandle: some View {
        Capsule()
            .fill(Color.white.opacity(0.35))
            .frame(width: 38, height: 4)
    }

    private var artworkView: some View {
        AsyncImage(url: URL(string: playerVM.currentTrack?.highResArtworkURL ?? "")) { img in
            img.resizable().aspectRatio(contentMode: .fill)
        } placeholder: {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.12))
                .overlay(Image(systemName: "music.note").font(.system(size: 64)).foregroundStyle(.white.opacity(0.4)))
        }
        .frame(width: 290, height: 290)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.55), radius: 24, x: 0, y: 12)
        .scaleEffect(playerVM.isPlaying ? 1.0 : 0.90)
        .animation(.spring(response: 0.45, dampingFraction: 0.65), value: playerVM.isPlaying)
        .padding(.top, 16)
    }

    private var trackInfo: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(playerVM.currentTrack?.title ?? "Not Playing")
                    .font(.title2).fontWeight(.bold).foregroundStyle(.white).lineLimit(2)
                Text(playerVM.currentTrack?.username ?? "")
                    .font(.callout).foregroundStyle(.white.opacity(0.65))
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    private var progressSection: some View {
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
            .font(.caption)
            .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var controlButtons: some View {
        HStack(spacing: 50) {
            Button { playerVM.skipPrevious() } label: {
                Image(systemName: "backward.fill").font(.title).foregroundStyle(.white)
            }

            // Play / Pause button
            Button { playerVM.togglePlayPause() } label: {
                ZStack {
                    Circle().fill(.white).frame(width: 74, height: 74)
                    if playerVM.playerState == .loading {
                        ProgressView().tint(.black)
                    } else {
                        Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.black)
                            .offset(x: playerVM.isPlaying ? 0 : 2)
                    }
                }
            }

            Button { playerVM.skipNext() } label: {
                Image(systemName: "forward.fill").font(.title).foregroundStyle(.white)
            }
        }
    }

    private var speedPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Playback Speed", systemImage: "gauge.with.dots.needle.67percent")
                .font(.caption).foregroundStyle(.white.opacity(0.6))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(speeds, id: \.self) { spd in
                        Button { playerVM.setSpeed(spd) } label: {
                            Text(speedLabel(spd))
                                .font(.callout).fontWeight(.semibold)
                                .padding(.horizontal, 18).padding(.vertical, 9)
                                .background(playerVM.playbackSpeed == spd ? Color.white : Color.white.opacity(0.15))
                                .foregroundStyle(playerVM.playbackSpeed == spd ? Color.black : Color.white)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: 54) {
            iconButton(icon: "quote.bubble", label: "Lyrics") { showLyrics = true }
            iconButton(icon: "list.bullet",  label: "Queue")  { showQueue  = true }
        }
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
