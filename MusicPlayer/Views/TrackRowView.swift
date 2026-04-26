import SwiftUI

struct TrackRowView: View {
    let track: Track
    let isLiked: Bool
    let onToggleLike: () -> Void
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 12) {
            ArtworkThumbnail(url: track.thumbnailArtworkURL)
                .overlay(alignment: .bottomTrailing) {
                    if track.source == .spotify {
                        Circle()
                            .fill(Color(red: 0.11, green: 0.73, blue: 0.33))
                            .frame(width: 13, height: 13)
                            .overlay(
                                Text("S")
                                    .font(.system(size: 7, weight: .black))
                                    .foregroundStyle(.black)
                            )
                            .offset(x: 3, y: 3)
                    }
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(themeManager.font(14, .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(track.username)
                    .font(themeManager.font(12))
                    .foregroundStyle(themeManager.current.primary.opacity(0.8))
                    .lineLimit(1)
            }

            Spacer()

            if track.source == .spotify && track.previewURL == nil {
                Text("preview")
                    .font(themeManager.font(10))
                    .foregroundStyle(.white.opacity(0.2))
            } else {
                Text(track.durationFormatted)
                    .font(themeManager.font(12))
                    .foregroundStyle(.white.opacity(0.3))
            }

            Button(action: onToggleLike) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 15))
                    .foregroundStyle(isLiked ? .pink : .white.opacity(0.2))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 16)
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
