import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        let progress = playerVM.duration > 0 ? playerVM.currentTime / playerVM.duration : 0

        ZStack(alignment: .bottom) {
            HStack(spacing: 12) {
                // Artwork
                AsyncImage(url: URL(string: playerVM.currentTrack?.thumbnailArtworkURL ?? "")) { img in
                    img.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.white.opacity(0.07)
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                // Track info
                VStack(alignment: .leading, spacing: 2) {
                    Text(playerVM.currentTrack?.title ?? "")
                        .font(themeManager.font(13, .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(playerVM.currentTrack?.username ?? "")
                        .font(themeManager.font(11))
                        .foregroundStyle(themeManager.current.primary.opacity(0.75))
                        .lineLimit(1)
                }

                Spacer()

                // Play / Pause
                Button { playerVM.togglePlayPause() } label: {
                    ZStack {
                        Circle()
                            .fill(themeManager.current.primary)
                            .frame(width: 36, height: 36)
                        Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(themeManager.current.onPrimary)
                            .offset(x: playerVM.isPlaying ? 0 : 1)
                    }
                }
                .buttonStyle(.plain)

                // Skip
                Button { playerVM.skipNext() } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            // Progress line at bottom
            GeometryReader { geo in
                Rectangle()
                    .fill(themeManager.current.primary.opacity(0.6))
                    .frame(width: geo.size.width * progress, height: 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(.linear(duration: 0.5), value: progress)
            }
            .frame(height: 2)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.07), lineWidth: 0.5)
        )
        .onTapGesture { playerVM.showingNowPlaying = true }
    }
}
