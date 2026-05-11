import SwiftUI
import PhotosUI

struct CustomizationView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var playerVM: PlayerViewModel
    @State private var tab: CTab = .cover
    @State private var coverPhotoItem: PhotosPickerItem?
    private var bg:     Color { themeManager.current.background }
    private var bgCard: Color { themeManager.current.card }
    private var fg:     Color { themeManager.current.foreground }

    enum CTab { case cover, slider, theme, font }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Live preview — always visible at top
                livePreview
                    .padding(.top, 16)

                // Filter pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        pill("Cover",  icon: "photo.on.rectangle.angled", t: .cover)
                        pill("Slider", icon: "slider.horizontal.3",       t: .slider)
                        pill("Theme",  icon: "paintpalette.fill",         t: .theme)
                        pill("Font",   icon: "textformat",                t: .font)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }

                Group {
                    switch tab {
                    case .cover:  coverTab
                    case .slider: sliderTab
                    case .theme:  themeTab
                    case .font:   fontTab
                    }
                }
                .padding(.top, 8)
            }
            .padding(.bottom, 120)
        }
        .background(bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Customization")
                    .font(.app(15, .bold))
                    .foregroundStyle(fg)
            }
        }
        .preferredColorScheme(themeManager.current.isDark ? .dark : .light)
        .onChange(of: coverPhotoItem) { _, item in
            Task {
                guard let data = try? await item?.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                themeManager.saveCustomCoverImage(image)
            }
        }
    }

    // MARK: - Live preview

    private var livePreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("LIVE PREVIEW")

            VStack(spacing: 0) {
                // Mini player row
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(
                            colors: [themeManager.current.primary.opacity(0.7),
                                     themeManager.current.primary.opacity(0.25)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 46, height: 46)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.75))
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Track Title")
                            .font(.app(14, .bold))
                            .foregroundStyle(fg)
                            .lineLimit(1)
                        Text("Artist Name")
                            .font(.app(12))
                            .foregroundStyle(fg.opacity(0.5))
                            .lineLimit(1)
                    }

                    Spacer()

                    HStack(spacing: 18) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(fg.opacity(0.45))
                        Image(systemName: "play.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(themeManager.current.primary)
                        Image(systemName: "forward.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(fg.opacity(0.45))
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(themeManager.current.card)

                Rectangle()
                    .fill(fg.opacity(0.06))
                    .frame(height: 0.5)

                // Theme + font badge row
                HStack(spacing: 6) {
                    Circle()
                        .fill(themeManager.current.primary)
                        .frame(width: 6, height: 6)
                    Text(themeManager.current.name)
                        .font(.app(11, .semibold))
                        .foregroundStyle(themeManager.current.primary)
                    Text("·")
                        .font(.app(11))
                        .foregroundStyle(fg.opacity(0.2))
                    Text(themeManager.appFont.label)
                        .font(.app(11))
                        .foregroundStyle(fg.opacity(0.4))
                    Spacer()
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(themeManager.current.background)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(themeManager.current.primary.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .animation(.easeInOut(duration: 0.3), value: themeManager.current.id)
            .animation(.easeInOut(duration: 0.3), value: themeManager.appFont)
        }
    }

    // MARK: - Pill button

    private func pill(_ title: String, icon: String, t: CTab) -> some View {
        let on = tab == t
        return Button { tab = t } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                Text(title).font(.app(13, .semibold))
            }
            .foregroundStyle(on ? themeManager.current.background : fg.opacity(0.65))
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(on ? fg : fg.opacity(0.08), in: Capsule())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.18), value: tab)
    }

    // MARK: - Cover tab

    private var coverTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader("COVER SOURCE")

            // Style cards row
            HStack(spacing: 14) {
                // Album Art
                let artOn = themeManager.coverStyle == .albumArt
                Button { themeManager.selectCover(.albumArt) } label: {
                    sourceCard(label: "Album Art", selected: artOn, accent: themeManager.current.primary) {
                        ZStack {
                            LinearGradient(colors: [Color(white: 0.28), Color(white: 0.06)],
                                           startPoint: .top, endPoint: .bottom)
                            Image(systemName: "music.note")
                                .font(.app(26, .light))
                                .foregroundStyle(.white.opacity(0.35))
                        }
                    }
                }
                .buttonStyle(.plain)

                // Custom Photo
                let photoOn = themeManager.coverStyle == .customPhoto
                PhotosPicker(selection: $coverPhotoItem, matching: .images) {
                    sourceCard(label: "Custom Photo", selected: photoOn, accent: themeManager.current.primary) {
                        if let img = themeManager.customCoverImage {
                            Image(uiImage: img)
                                .resizable().aspectRatio(contentMode: .fill)
                        } else {
                            ZStack {
                                Color(white: 0.14)
                                VStack(spacing: 6) {
                                    Image(systemName: "plus")
                                        .font(.app(22, .light))
                                        .foregroundStyle(.white.opacity(0.35))
                                    Text("Add Photo")
                                        .font(.app(9, .bold)).kerning(1)
                                        .foregroundStyle(.white.opacity(0.25))
                                }
                            }
                        }
                    }
                }
                .buttonStyle(.plain)

                // Hidden
                let hiddenOn = themeManager.coverStyle == .hidden
                Button { themeManager.selectCover(.hidden) } label: {
                    sourceCard(label: "Hidden", selected: hiddenOn, accent: themeManager.current.primary) {
                        ZStack {
                            Color(white: 0.10)
                            Image(systemName: "eye.slash")
                                .font(.app(22, .light))
                                .foregroundStyle(.white.opacity(0.25))
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)

            // Library — show saved cover if any
            sectionHeader("LIBRARY")

            if let img = themeManager.customCoverImage {
                HStack(spacing: 14) {
                    Image(uiImage: img)
                        .resizable().aspectRatio(1, contentMode: .fill)
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Custom Cover")
                            .font(.app(14, .semibold)).foregroundStyle(fg)
                        Text("Tap replace to update")
                            .font(.app(11)).foregroundStyle(fg.opacity(0.35))
                    }
                    Spacer()

                    PhotosPicker(selection: $coverPhotoItem, matching: .images) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.app(16)).foregroundStyle(fg.opacity(0.45))
                    }

                    Button { themeManager.deleteCustomCoverImage() } label: {
                        Image(systemName: "trash")
                            .font(.app(16)).foregroundStyle(.red.opacity(0.6))
                    }
                }
                .padding(16)
                .background(bgCard, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 16)
            } else {
                PhotosPicker(selection: $coverPhotoItem, matching: .images) {
                    HStack(spacing: 12) {
                        Image(systemName: "photo.badge.plus")
                            .font(.app(20)).foregroundStyle(themeManager.current.primary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add Custom Cover")
                                .font(.app(14, .semibold)).foregroundStyle(fg)
                            Text("Choose from your photo library")
                                .font(.app(11)).foregroundStyle(fg.opacity(0.35))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.app(12, .semibold)).foregroundStyle(fg.opacity(0.2))
                    }
                    .padding(16)
                    .background(bgCard, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Slider tab

    private var sliderTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader("SLIDER TYPE")
            HStack(spacing: 12) {
                ForEach(SliderType.allCases, id: \.rawValue) { type in
                    SliderTypeCard(
                        type: type,
                        isSelected: themeManager.sliderType == type,
                        accent: themeManager.current.primary,
                        bgCard: bgCard,
                        appForeground: fg
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) { themeManager.selectSlider(type) }
                    }
                }
            }
            .padding(.horizontal, 16)

            // Crossfade
            sectionHeader("CROSSFADE")

            VStack(spacing: 12) {
                HStack {
                    Text(playerVM.crossfadeDuration == 0 ? "Off" : "\(Int(playerVM.crossfadeDuration))s")
                        .font(.app(13, .semibold))
                        .foregroundStyle(themeManager.current.primary)
                        .frame(width: 36, alignment: .leading)
                    Slider(value: Binding(
                        get: { playerVM.crossfadeDuration },
                        set: { playerVM.setCrossfade(Double(Int($0))) }
                    ), in: 0...12, step: 1)
                    .tint(themeManager.current.primary)
                }
                .padding(.horizontal, 16)

                Text("Smoothly blend between tracks. 0 = gapless (instant transition, no silence).")
                    .font(.app(11))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Theme tab

    private var themeTab: some View {
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return VStack(alignment: .leading, spacing: 20) {
            sectionHeader("THEME")
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(AppTheme.all) { theme in
                    ThemeCard(theme: theme,
                              isSelected: themeManager.current.id == theme.id,
                              bgCard: bgCard,
                              appForeground: fg)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                themeManager.select(theme)
                            }
                        }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Font tab

    private var fontTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Monocraft quick toggle
            sectionHeader("MONOCRAFT")

            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(themeManager.current.primary.opacity(0.12))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text("Mc")
                            .font(AppFont.minecraft.font(13, .bold))
                            .foregroundStyle(themeManager.current.primary)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text("Monocraft")
                        .font(.app(15, .semibold))
                        .foregroundStyle(fg)
                    Text("Pixel-style bitmap font by IdreesInc")
                        .font(.app(12))
                        .foregroundStyle(fg.opacity(0.45))
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { themeManager.appFont == .minecraft },
                    set: { use in
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            themeManager.selectFont(use ? .minecraft : .system)
                        }
                    }
                ))
                .tint(themeManager.current.primary)
                .labelsHidden()
            }
            .padding(16)
            .background(bgCard, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 16)

            // All font styles
            sectionHeader("FONT STYLE")

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(AppFont.allCases, id: \.self) { f in
                    fontCard(f)
                }
            }
            .padding(.horizontal, 16)

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "info.circle")
                        .font(.app(14))
                        .foregroundStyle(themeManager.current.primary.opacity(0.6))
                    Text("Font applies throughout the app: track titles, artist names, menus, and controls.")
                        .font(.app(12))
                        .foregroundStyle(fg.opacity(0.45))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
            }
            .background(bgCard, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)
        }
    }

    private func fontCard(_ f: AppFont) -> some View {
        let selected = themeManager.appFont == f
        let accent   = themeManager.current.primary

        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                themeManager.selectFont(f)
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                Text(f.preview)
                    .font(f.font(18, .semibold))
                    .foregroundStyle(fg)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Divider().background(fg.opacity(0.08))

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(f.label)
                            .font(.app(12, .semibold))
                            .foregroundStyle(selected ? accent : fg)
                        Text(fontSubtitle(f))
                            .font(.app(10))
                            .foregroundStyle(fg.opacity(0.4))
                    }
                    Spacer()
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.app(16))
                            .foregroundStyle(accent)
                    }
                }
            }
            .padding(14)
            .background(bgCard, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(selected ? accent : fg.opacity(0.06), lineWidth: selected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: themeManager.appFont)
    }

    // MARK: - Helpers

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.app(10, .black)).kerning(2)
            .foregroundStyle(fg.opacity(0.35))
            .padding(.horizontal, 16)
    }

    private func fontSubtitle(_ f: AppFont) -> String {
        switch f {
        case .system:    return "SF Pro · system default"
        case .rounded:   return "SF Rounded · soft edges"
        case .serif:     return "New York · editorial"
        case .mono:      return "SF Mono · pixel / retro"
        case .minecraft: return "Monocraft · by IdreesInc"
        }
    }

    @ViewBuilder
    private func sourceCard<Preview: View>(label: String, selected: Bool, accent: Color,
                                           @ViewBuilder preview: () -> Preview) -> some View {
        VStack(spacing: 0) {
            preview()
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(alignment: .topTrailing) {
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.app(20))
                            .foregroundStyle(accent)
                            .padding(8)
                    }
                }

            Text(label)
                .font(.app(12, .semibold)).foregroundStyle(fg)
                .padding(.top, 8)
        }
        .padding(.bottom, 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(selected ? accent : Color.clear, lineWidth: 2)
        )
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Slider type card

private struct SliderTypeCard: View {
    let type: SliderType
    let isSelected: Bool
    let accent: Color
    let bgCard: Color
    let appForeground: Color

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 44)
                sliderPreview
                    .padding(.horizontal, 10)
            }

            Text(type.label)
                .font(.app(11, .semibold))
                .foregroundStyle(isSelected ? accent : appForeground.opacity(0.55))
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(bgCard, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? accent : appForeground.opacity(0.07), lineWidth: isSelected ? 1.5 : 0.5)
        )
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    @ViewBuilder private var sliderPreview: some View {
        switch type {
        case .classic:
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12)).frame(height: 4)
                    Capsule().fill(accent).frame(width: geo.size.width * 0.6, height: 4)
                    Circle()
                        .fill(.white)
                        .frame(width: 14, height: 14)
                        .offset(x: geo.size.width * 0.6 - 7)
                }
                .frame(maxHeight: .infinity)
            }
            .frame(height: 20)
        case .waveform2:
            HStack(spacing: 2) {
                ForEach(0..<18, id: \.self) { i in
                    let heights: [CGFloat] = [8,12,6,14,10,16,8,12,6,10,14,8,16,10,6,12,8,14]
                    let h = heights[i % heights.count]
                    let filled = i < 11
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(filled ? accent : Color.white.opacity(0.15))
                        .frame(width: 3, height: h)
                }
            }
        case .glimmer:
            TimelineView(.animation(minimumInterval: 1.0 / 20)) { tl in
                let phase = CGFloat(
                    tl.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: 2.0) / 2.0
                )
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 5)
                        Capsule()
                            .fill(LinearGradient(
                                stops: [
                                    .init(color: accent,                    location: 0),
                                    .init(color: accent,                    location: max(0, phase - 0.18)),
                                    .init(color: Color.white.opacity(0.90), location: phase),
                                    .init(color: accent,                    location: min(1, phase + 0.18)),
                                    .init(color: accent,                    location: 1),
                                ],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(width: geo.size.width * 0.6, height: 5)
                        Circle()
                            .fill(.white)
                            .frame(width: 13, height: 13)
                            .offset(x: geo.size.width * 0.6 - 6.5)
                    }
                    .frame(maxHeight: .infinity)
                }
                .frame(height: 20)
            }
        }
    }
}

// MARK: - Theme card

private struct ThemeCard: View {
    let theme: AppTheme
    let isSelected: Bool
    let bgCard: Color
    let appForeground: Color

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(theme.background)
                    .frame(height: 48)
                HStack(spacing: 6) {
                    ForEach(Array(theme.swatches.prefix(3).enumerated()), id: \.0) { _, c in
                        Circle().fill(c).frame(width: 18, height: 18)
                    }
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.app(16))
                            .foregroundStyle(theme.primary)
                    }
                }
                .padding(.horizontal, 10)
            }

            Text(theme.name)
                .font(.app(11, .semibold))
                .foregroundStyle(isSelected ? theme.primary : appForeground.opacity(0.55))
        }
        .padding(10)
        .background(bgCard, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? theme.primary : appForeground.opacity(0.07), lineWidth: isSelected ? 1.5 : 0.5)
        )
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
