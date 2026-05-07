import SwiftUI

// MARK: - Shimmer skeleton base

struct SkeletonView: View {
    var cornerRadius: CGFloat = 6
    @State private var phase: CGFloat = -0.4

    var body: some View {
        GeometryReader { _ in
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.white.opacity(0.07))
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.13), .clear],
                            startPoint: UnitPoint(x: phase,       y: 0),
                            endPoint:   UnitPoint(x: phase + 0.4, y: 0)
                        )
                    )
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                phase = 1.1
            }
        }
    }
}

// MARK: - Track row skeleton

struct SkeletonTrackRow: View {
    var body: some View {
        HStack(spacing: 12) {
            SkeletonView(cornerRadius: 10)
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 7) {
                SkeletonView(cornerRadius: 4)
                    .frame(width: 160, height: 12)
                SkeletonView(cornerRadius: 4)
                    .frame(width: 100, height: 10)
            }
            Spacer()
            SkeletonView(cornerRadius: 4)
                .frame(width: 36, height: 10)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }
}

// MARK: - Card skeleton (horizontal scroll)

struct SkeletonCard: View {
    var width:  CGFloat = 132
    var height: CGFloat = 132

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SkeletonView(cornerRadius: 14)
                .frame(width: width, height: height)
            SkeletonView(cornerRadius: 4)
                .frame(width: width * 0.75, height: 11)
            SkeletonView(cornerRadius: 4)
                .frame(width: width * 0.5, height: 10)
        }
    }
}
