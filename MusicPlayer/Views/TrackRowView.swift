import SwiftUI

/// Reusable single-row component used in Search, Recently Played, and Queue.
struct TrackRowView: View {
    let track: Track
    var isPlaying: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            ArtworkThumbnail(url: track.thumbnailArtworkURL)

            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.body)
                    .fontWeight(isPlaying ? .semibold : .regular)
                    .foregroundStyle(isPlaying ? Color.accentColor : .primary)
                    .lineLimit(1)

                Text(track.username)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if isPlaying {
                Image(systemName: "waveform")
                    .symbolEffect(.variableColor.iterative, isActive: true)
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
            }

            Text(track.durationFormatted)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

/// Square artwork thumbnail with placeholder
struct ArtworkThumbnail: View {
    let url: String?
    var size: CGFloat = 50

    var body: some View {
        AsyncImage(url: URL(string: url ?? "")) { phase in
            switch phase {
            case .success(let img):
                img.resizable().aspectRatio(contentMode: .fill)
            default:
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray5))
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundStyle(.secondary)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
