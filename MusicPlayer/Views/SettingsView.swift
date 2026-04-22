import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager

    private let bg      = Color(red: 0.075, green: 0.075, blue: 0.075)
    private let bgCard  = Color(red: 0.110, green: 0.110, blue: 0.110)
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    settingSection(title: "CUSTOMIZATION") {
                        NavigationLink {
                            CustomizationView().environmentObject(themeManager)
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(themeManager.current.primary.opacity(0.15))
                                        .frame(width: 42, height: 42)
                                    Image(systemName: "paintbrush.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(themeManager.current.primary)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Customization")
                                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                                    Text("Background, cover & slider")
                                        .font(.system(size: 12)).foregroundStyle(.white.opacity(0.4))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.3))
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    settingSection(title: "THEME") {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(AppTheme.all) { theme in
                                ThemeCard(theme: theme,
                                          isSelected: themeManager.current.id == theme.id,
                                          bgCard: bgCard)
                                    .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { themeManager.select(theme) } }
                            }
                        }
                    }
                }
                .padding(.bottom, 120)
            }
            .background(bg.ignoresSafeArea())
            .navigationTitle("General")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(bg, for: .navigationBar)
            .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Section container

private extension SettingsView {
    @ViewBuilder
    func settingSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        let bgCard = Color(red: 0.110, green: 0.110, blue: 0.110)
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 10, weight: .black)).kerning(2)
                .foregroundStyle(.white.opacity(0.35))

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(bgCard, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
}

// MARK: - Slider type card

struct SliderTypeCard: View {
    let type: SliderType
    let isSelected: Bool
    let accent: Color
    let bgCard: Color

    var body: some View {
        VStack(spacing: 12) {
            sliderPreview
                .frame(height: 32)

            Text(type.label)
                .font(.custom("Courier", size: 11)).bold()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 10).padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(bgCard, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? accent : Color.clear, lineWidth: 2)
        )
    }

    @ViewBuilder
    private var sliderPreview: some View {
        let fill = 0.38

        switch type {
        case .waveform1:
            Canvas { ctx, size in
                var rng = 54321 &* 1664525 &+ 1013904223
                let bars: [CGFloat] = (0..<28).map { _ in
                    rng = rng &* 1664525 &+ 1013904223
                    return 0.2 + CGFloat((rng >> 16) & 0xFFFF) / 65535.0 * 0.8
                }
                let step = size.width / CGFloat(bars.count)
                let barW = max(1.5, step * 0.72)
                for (i, h) in bars.enumerated() {
                    let filled = Double(i) / Double(bars.count) < fill
                    let barH = h * size.height
                    let rect = CGRect(x: CGFloat(i)*step+(step-barW)/2,
                                      y: (size.height-barH)/2, width: barW, height: barH)
                    ctx.fill(Path(roundedRect: rect, cornerRadius: barW/2),
                             with: .color(filled ? accent : Color.white.opacity(0.22)))
                }
            }

        case .waveform2:
            Canvas { ctx, size in
                var rng = 54321 &* 1664525 &+ 1013904223
                let bars: [CGFloat] = (0..<28).map { _ in
                    rng = rng &* 1664525 &+ 1013904223
                    return 0.2 + CGFloat((rng >> 16) & 0xFFFF) / 65535.0 * 0.8
                }
                let step = size.width / CGFloat(bars.count)
                let barW = max(1.5, step * 0.65)
                let cy   = size.height / 2
                for (i, h) in bars.enumerated() {
                    let filled = Double(i) / Double(bars.count) < fill
                    let halfH  = h * cy * 0.9
                    let rect = CGRect(x: CGFloat(i)*step+(step-barW)/2,
                                      y: cy-halfH, width: barW, height: halfH*2)
                    ctx.fill(Path(roundedRect: rect, cornerRadius: barW/2),
                             with: .color(filled ? accent : Color.white.opacity(0.22)))
                }
            }

        case .classic:
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.15)).frame(height: 5)
                    Capsule().fill(accent)
                        .frame(width: geo.size.width * fill, height: 5)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
        }
    }
}

// MARK: - Theme card

private struct ThemeCard: View {
    let theme: AppTheme
    let isSelected: Bool
    let bgCard: Color

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(bgCard)

            // Selection ring
            if isSelected {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.white, lineWidth: 2)
            }

            // Swatches top-left + selection dot top-right
            VStack {
                HStack(alignment: .top) {
                    HStack(spacing: 6) {
                        ForEach(theme.swatches.indices, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 7)
                                .fill(theme.swatches[i])
                                .frame(width: 28, height: 28)
                        }
                    }
                    Spacer()
                    if isSelected {
                        Circle().fill(.white).frame(width: 16, height: 16)
                    }
                }
                .padding(12)
                Spacer()
            }

            // Name bottom-left
            Text(theme.name)
                .font(.custom("Courier", size: 14)).bold()
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.bottom, 12)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
