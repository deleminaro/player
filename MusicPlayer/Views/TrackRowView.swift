import SwiftUI

struct TrackRowView: View {
    let track: Track
    let isLiked: Bool
    let onToggleLike: () -> Void

    private let primary = Color(red: 0.753, green: 0.757, blue: 1.0)

    var body: some View {
        HStack(spacing: 14) {
            ArtworkThumbnail(url: track.thumbnailArtworkURL)

            VStack(alignment: .leading, spacing: 3) {
                Text(track.title.uppercased())
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(track.username.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(primary)
                    .kerning(1.5)
                    .lineLimit(1)
            }

            Spacer()

            Text(track.durationFormatted)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.3))

            Button(action: onToggleLike) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 14))
                    .foregroundStyle(isLiked ? .pink : .white.opacity(0.25))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
    }
}

// MARK: - Image cache

private final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()
    private init() { cache.countLimit = 200 }

    func get(_ key: String) -> UIImage? { cache.object(forKey: key as NSString) }
    func set(_ image: UIImage, for key: String) { cache.setObject(image, forKey: key as NSString) }
}

// MARK: - Cached artwork thumbnail

struct ArtworkThumbnail: View {
    let url: String?
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.07))

            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.2))
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .task(id: url) { await loadImage() }
    }

    private func loadImage() async {
        guard let urlStr = url, !urlStr.isEmpty else { return }
        if let cached = ImageCache.shared.get(urlStr) { image = cached; return }
        guard let url = URL(string: urlStr),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let uiImage = UIImage(data: data) else { return }
        ImageCache.shared.set(uiImage, for: urlStr)
        image = uiImage
    }
}
