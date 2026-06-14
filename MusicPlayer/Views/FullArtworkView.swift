import SwiftUI

struct FullArtworkView: View {
    let track: Track?
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    @State private var scale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var dragOffset: CGSize = .zero
    @GestureState private var pinchScale: CGFloat = 1.0

    private var artworkURL: URL? {
        guard let t = track else { return nil }
        return URL(string: t.highResArtworkURL ?? t.artworkURL ?? "")
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Blurred background
            if let url = artworkURL {
                AsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: { Color.clear }
                    .ignoresSafeArea()
                    .blur(radius: 50)
                    .opacity(0.35)
                    .allowsHitTesting(false)
            }

            // Main zoomable artwork
            GeometryReader { geo in
                let totalScale = max(1.0, min(5.0, scale * pinchScale))
                ZStack {
                    if let url = artworkURL {
                        AsyncImage(url: url) { img in
                            img.resizable().aspectRatio(contentMode: .fit)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.08))
                        }
                    } else {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.08))
                        Image(systemName: "music.note")
                            .font(.system(size: 60, weight: .ultraLight))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipShape(RoundedRectangle(cornerRadius: totalScale > 1.05 ? 0 : 24))
                .shadow(color: .black.opacity(0.55), radius: 40, y: 20)
                .scaleEffect(totalScale)
                .offset(x: panOffset.width + dragOffset.width,
                        y: panOffset.height + dragOffset.height)
                .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.8), value: scale)
            }
            .ignoresSafeArea()

            // Dismiss button
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 40, height: 40)
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(ScaleButtonStyle(scale: 0.88))
                    .padding(.leading, 20)
                    .padding(.top, 12)
                    Spacer()
                }
                Spacer()
                // Track title / artist overlay
                if let t = track {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(t.title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        Text(t.username)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
                    .background(
                        LinearGradient(colors: [.clear, .black.opacity(0.6)],
                                       startPoint: .top, endPoint: .bottom)
                            .ignoresSafeArea()
                    )
                }
            }
        }
        .gesture(
            MagnificationGesture()
                .updating($pinchScale) { value, state, _ in
                    state = value
                }
                .onEnded { value in
                    let newScale = max(1.0, min(5.0, scale * value))
                    scale = newScale
                    if newScale <= 1.01 {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            panOffset = .zero
                        }
                    }
                }
        )
        .simultaneousGesture(
            DragGesture()
                .onChanged { v in
                    if scale > 1.01 {
                        dragOffset = v.translation
                    } else {
                        // Swipe-down to dismiss when not zoomed
                        dragOffset = CGSize(width: 0, height: max(0, v.translation.height))
                    }
                }
                .onEnded { v in
                    if scale > 1.01 {
                        panOffset.width += dragOffset.width
                        panOffset.height += dragOffset.height
                        dragOffset = .zero
                    } else {
                        dragOffset = .zero
                        if v.translation.height > 80 || v.predictedEndTranslation.height > 200 {
                            dismiss()
                        }
                    }
                }
        )
        .preferredColorScheme(.dark)
    }
}
