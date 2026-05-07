import SwiftUI

struct TrackRowView: View {
    let track: Track
    let isLiked: Bool
    let onToggleLike: () -> Void
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager

    private var isCurrentTrack: Bool { playerVM.currentTrack?.id == track.id }

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
                    .foregroundStyle(isCurrentTrack ? themeManager.current.primary : .white)
                    .lineLimit(1)
                Text(track.username)
                    .font(themeManager.font(12))
                    .foregroundStyle(themeManager.current.primary.opacity(0.8))
                    .lineLimit(1)
            }

            Spacer()

            if isCurrentTrack {
                NowPlayingBarsView(isPlaying: playerVM.isPlaying, color: themeManager.current.primary)
                    .padding(.trailing, 4)
            } else if track.source == .spotify && track.previewURL == nil {
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
                    .foregroundStyle(isLiked ? .pink : .white.opacity(0.25))
                    .scaleEffect(isLiked ? 1.08 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.5), value: isLiked)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .light), trigger: isLiked)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }
}

// MARK: - Animated now-playing bars

struct NowPlayingBarsView: View {
    let isPlaying: Bool
    let color: Color

    var body: some View {
        TimelineView(isPlaying ? .animation(minimumInterval: 1.0 / 24) : .animation(paused: true)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 2) {
                bar(height: isPlaying ? wave(t, freq: 3.1, phase: 0.0) : 5)
                bar(height: isPlaying ? wave(t, freq: 4.7, phase: 1.3) : 5)
                bar(height: isPlaying ? wave(t, freq: 3.9, phase: 2.5) : 5)
            }
        }
        .frame(width: 14, height: 14)
    }

    private func wave(_ t: Double, freq: Double, phase: Double) -> CGFloat {
        let v = (sin(t * freq + phase) + 1) * 0.5
        return 3 + v * 11
    }

    private func bar(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(color)
            .frame(width: 3, height: max(3, height))
    }
}

// MARK: - Image cache

final class ImageCache {
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
