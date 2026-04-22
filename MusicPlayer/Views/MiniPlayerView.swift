import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager

    private var bg:       Color { themeManager.current.card }

    var body: some View {
        let progress = playerVM.duration > 0 ? playerVM.currentTime / playerVM.duration : 0

        ZStack(alignment: .bottom) {
            HStack(spacing: 12) {
                // Artwork
                AsyncImage(url: URL(string: playerVM.currentTrack?.thumbnailArtworkURL ?? "")) { img in
                    img.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.08))
                }
                .frame(width: 42, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                // Track info
                VStack(alignment: .leading, spacing: 2) {
                    Text((playerVM.currentTrack?.title ?? "").uppercased())
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text((playerVM.currentTrack?.username ?? "").uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(themeManager.current.primary)
                        .kerning(1.5)
                        .lineLimit(1)
                }

                Spacer()

                // Play / Pause
                Button {
                    playerVM.togglePlayPause()
                } label: {
                    ZStack {
                        Circle().fill(themeManager.current.primary).frame(width: 38, height: 38)
                        Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(themeManager.current.onPrimary)
                            .offset(x: playerVM.isPlaying ? 0 : 1)
                    }
                }

                // Skip
                Button { playerVM.skipNext() } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Progress line at bottom
            GeometryReader { geo in
                Rectangle()
                    .fill(themeManager.current.primary)
                    .frame(width: geo.size.width * progress, height: 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 2)
        }
        .background(
            ZStack {
                bg
                Color.white.opacity(0.04)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 8)
        .onTapGesture { playerVM.showingNowPlaying = true }
    }
}
