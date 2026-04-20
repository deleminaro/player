import SwiftUI

struct TrackRowView: View {
    let track: Track
    @State private var isPressed = false

    private let primary = Color(red: 0.753, green: 0.757, blue: 1.0)

    var body: some View {
        HStack(spacing: 14) {
            ArtworkThumbnail(url: track.thumbnailArtworkURL)

            VStack(alignment: .leading, spacing: 3) {
                Text(track.title.uppercased())
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(isPressed ? Color.black : Color.white)
                    .lineLimit(1)
                Text(track.username.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(isPressed ? Color.black.opacity(0.6) : primary)
                    .kerning(1.5)
                    .lineLimit(1)
            }

            Spacer()

            Text(track.durationFormatted)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(isPressed ? Color.black.opacity(0.5) : Color.white.opacity(0.3))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(isPressed ? Color.white : Color.clear)
        .animation(.easeInOut(duration: 0.15), value: isPressed)
        .contentShape(Rectangle())
    }
}

struct ArtworkThumbnail: View {
    let url: String?

    var body: some View {
        AsyncImage(url: URL(string: url ?? "")) { img in
            img.resizable().aspectRatio(contentMode: .fill)
        } placeholder: {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.2))
                )
        }
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
