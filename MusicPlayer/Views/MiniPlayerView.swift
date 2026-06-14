import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        let progress = playerVM.duration > 0 ? playerVM.currentTime / playerVM.duration : 0
        let accent   = themeManager.current.primary

        ZStack(alignment: .bottom) {
            HStack(spacing: 12) {
                // Artwork
                ZStack {
                    RoundedRectangle(cornerRadius: 11)
                        .fill(Color.white.opacity(0.07))
                    AsyncImage(url: URL(string: playerVM.currentTrack?.thumbnailArtworkURL ?? "")) { img in
                        img.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: { Color.clear }
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 11))
                .shadow(color: .black.opacity(0.25), radius: 8, y: 2)

                // Track info
                VStack(alignment: .leading, spacing: 2) {
                    Text(playerVM.currentTrack?.title ?? "")
                        .font(themeManager.font(13, .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .contentTransition(.opacity)
                        .animation(.easeInOut(duration: 0.25), value: playerVM.currentTrack?.id)
                    Text(playerVM.currentTrack?.username ?? "")
                        .font(themeManager.font(11))
                        .foregroundStyle(accent.opacity(0.75))
                        .lineLimit(1)
                        .contentTransition(.opacity)
                        .animation(.easeInOut(duration: 0.25).delay(0.05), value: playerVM.currentTrack?.id)
                }

                Spacer()

                // Play / Pause
                Button { playerVM.togglePlayPause() } label: {
                    ZStack {
                        Circle()
                            .fill(accent)
                            .frame(width: 44, height: 44)
                        if playerVM.playerState == .loading {
                            ProgressView().tint(themeManager.current.onPrimary).scaleEffect(0.8)
                        } else {
                            Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                                .font(.app(15, .bold))
                                .foregroundStyle(themeManager.current.onPrimary)
                                .offset(x: playerVM.isPlaying ? 0 : 1)
                                .contentTransition(.symbolEffect(.replace))
                        }
                    }
                }
                .buttonStyle(ScaleButtonStyle(scale: 0.88))
                .sensoryFeedback(.impact(weight: .medium), trigger: playerVM.isPlaying)

                // Skip forward
                Button { playerVM.skipNext() } label: {
                    Image(systemName: "forward.fill")
                        .font(.app(16, .semibold))
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(ScaleButtonStyle(scale: 0.88))
                .sensoryFeedback(.impact(weight: .light), trigger: playerVM.currentTrack?.id)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            // Progress bar — bottom edge
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08)).frame(height: 2.5)
                    Capsule()
                        .fill(accent.opacity(0.7))
                        .frame(width: geo.size.width * progress, height: 2.5)
                        .animation(.linear(duration: 0.5), value: progress)
                }
            }
            .frame(height: 2.5)
            .padding(.horizontal, 14)
        }
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        )
        .onTapGesture { playerVM.showingNowPlaying = true }
    }
}
