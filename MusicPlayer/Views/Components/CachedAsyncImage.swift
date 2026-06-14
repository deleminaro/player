import SwiftUI

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: String?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var image: UIImage?

    var body: some View {
        if let img = image {
            content(Image(uiImage: img))
        } else {
            placeholder()
                .task(id: url) { await load() }
        }
    }

    private func load() async {
        guard let str = url, !str.isEmpty else { return }
        if let cached = ImageCache.shared.get(str) { image = cached; return }
        guard let u = URL(string: str),
              let (data, _) = try? await URLSession.shared.data(from: u),
              let uiImg = UIImage(data: data) else { return }
        ImageCache.shared.set(uiImg, for: str)
        image = uiImg
    }
}
