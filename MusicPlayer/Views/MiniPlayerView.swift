import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject var playerVM: PlayerViewModel

    var body: some View {
        HStack(spacing: 12) {
            ArtworkThumbnail(url: playerVM.currentTrack?.thumbnailArtworkURL, size: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(playerVM.currentTrack?.title ?? "")
                    .font(.callout).fontWeight(.medium).lineLimit(1)
                Text(playerVM.currentTrack?.username ?? "")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }

            Spacer(minLength: 0)

            // Play / Pause
            Button { playerVM.togglePlayPause() } label: {
                Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Skip forward
            Button { playerVM.skipNext() } label: {
                Image(systemName: "forward.fill")
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
        .padding(.horizontal, 10)
        .onTapGesture { playerVM.showingNowPlaying = true }
    }
}
