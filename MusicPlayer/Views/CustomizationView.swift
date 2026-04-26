import SwiftUI
import PhotosUI

struct CustomizationView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var tab: CTab = .background
    @State private var photoItem: PhotosPickerItem?
    @State private var coverPhotoItem: PhotosPickerItem?

    private var bg:     Color { themeManager.current.background }
    private var bgCard: Color { themeManager.current.card }

    enum CTab { case background, cover, slider, theme, font }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Filter pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        pill("Background", icon: "photo.fill",                t: .background)
                        pill("Cover",      icon: "photo.on.rectangle.angled", t: .cover)
                        pill("Slider",     icon: "slider.horizontal.3",       t: .slider)
                        pill("Theme",      icon: "paintpalette.fill",         t: .theme)
                        pill("Font",       icon: "textformat",                t: .font)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }

                Group {
                    switch tab {
                    case .background: backgroundTab
                    case .cover:      coverTab
                    case .slider:     sliderTab
                    case .theme:      themeTab
                    case .font:       fontTab
                    }
                }
                .padding(.top, 8)
            }
            .padding(.bottom, 120)
        }
        .background(bg.ignoresSafeArea())
        .navigationTitle("Customization")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .preferredColorScheme(.dark)
        .onChange(of: photoItem) { _, item in
            Task {
                guard let data = try? await item?.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                themeManager.saveCustomWallpaper(image)
            }
        }
        .onChange(of: coverPhotoItem) { _, item in
            Task {
                guard let data = try? await item?.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                themeManager.saveCustomCoverImage(image)
            }
        }
    }

    // MARK: - Pill button

    private func pill(_ title: String, icon: String, t: CTab) -> some View {
        let on = tab == t
        return Button { tab = t } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                Text(title).font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(on ? .black : .white.opacity(0.65))
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(on ? .white : Color.white.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.18), value: tab)
    }

    // MARK: - Background tab

    private var backgroundTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader("BACKGROUND SOURCE")

            HStack(spacing: 14) {
                // Music cover
                let coverOn = themeManager.backgroundStyle == .musicCover
                Button { themeManager.selectBackground(.musicCover) } label: {
                    sourceCard(
                        label: "Music Cover",
                        selected: coverOn,
                        accent: themeManager.current.primary
                    ) {
                        ZStack {
                            LinearGradient(colors: [Color(white: 0.28), Color(white: 0.06)],
                                           startPoint: .top, endPoint: .bottom)
                            VStack(spacing: 6) {
                                Image(systemName: "music.note")
                                    .font(.system(size: 26, weight: .light))
                                    .foregroundStyle(.white.opacity(0.35))
                                Text("Album Art")
                                    .font(.system(size: 9, weight: .bold)).kerning(1)
                                    .foregroundStyle(.white.opacity(0.25))
                            }
                        }
                    }
                }
                .buttonStyle(.plain)

                // Custom photo
                let photoOn = themeManager.backgroundStyle == .customPhoto
                PhotosPicker(selection: $photoItem, matching: .images) {
                    sourceCard(
                        label: "Custom Photo",
                        selected: photoOn,
                        accent: themeManager.current.primary
                    ) {
                        if let img = themeManager.customWallpaper {
                            Image(uiImage: img)
                                .resizable().aspectRatio(contentMode: .fill)
                        } else {
                            ZStack {
                                Color(white: 0.14)
                                VStack(spacing: 6) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 22, weight: .light))
                                        .foregroundStyle(.white.opacity(0.35))
                                    Text("Add Photo")
                                        .font(.system(size: 9, weight: .bold)).kerning(1)
                                        .foregroundStyle(.white.opacity(0.25))
                                }
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)

            // Library
            sectionHeader("LIBRARY")

            if let img = themeManager.customWallpaper {
                HStack(spacing: 14) {
                    Image(uiImage: img)
                        .resizable().aspectRatio(1, contentMode: .fill)
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Custom Wallpaper")
                            .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                        Text("Tap to replace")
                            .font(.system(size: 11)).foregroundStyle(.white.opacity(0.35))
                    }
                    Spacer()

                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 16)).foregroundStyle(.white.opacity(0.45))
                    }
                }
                .padding(16)
                .background(bgCard, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 16)
            } else {
                emptyCard(icon: "photo.on.rectangle", title: "Library", subtitle: "No items")
            }

            // Presets
            sectionHeader("PRESETS")
            emptyCard(icon: "cube", title: "Presets", subtitle: "No saved presets")
        }
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
                                .font(.system(size: 26, weight: .light))
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
                                        .font(.system(size: 22, weight: .light))
                                        .foregroundStyle(.white.opacity(0.35))
                                    Text("Add Photo")
                                        .font(.system(size: 9, weight: .bold)).kerning(1)
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
                                .font(.system(size: 22, weight: .light))
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
                            .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                        Text("Tap replace to update")
                            .font(.system(size: 11)).foregroundStyle(.white.opacity(0.35))
                    }
                    Spacer()

                    PhotosPicker(selection: $coverPhotoItem, matching: .images) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 16)).foregroundStyle(.white.opacity(0.45))
                    }

                    Button { themeManager.deleteCustomCoverImage() } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 16)).foregroundStyle(.red.opacity(0.6))
                    }
                }
                .padding(16)
                .background(bgCard, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 16)
            } else {
                PhotosPicker(selection: $coverPhotoItem, matching: .images) {
                    HStack(spacing: 12) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 20)).foregroundStyle(themeManager.current.primary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add Custom Cover")
                                .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                            Text("Choose from your photo library")
                                .font(.system(size: 11)).foregroundStyle(.white.opacity(0.35))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.2))
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
                        bgCard: bgCard
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) { themeManager.selectSlider(type) }
                    }
                }
            }
            .padding(.horizontal, 16)
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
                              bgCard: bgCard)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) { themeManager.select(theme) }
                        }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .black)).kerning(2)
            .foregroundStyle(.white.opacity(0.35))
            .padding(.horizontal, 16)
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
                            .font(.system(size: 20))
                            .foregroundStyle(accent)
                            .padding(8)
                    }
                }

            Text(label)
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                .padding(.top, 8)
        }
        .padding(.bottom, 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(selected ? accent : Color.clear, lineWidth: 2)
        )
        .frame(maxWidth: .infinity)
    }

    private func emptyCard(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16)).foregroundStyle(.white.opacity(0.4))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                    Text(subtitle).font(.system(size: 11)).foregroundStyle(.white.opacity(0.35))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.2))
            }
            .padding(16)

            Divider().background(Color.white.opacity(0.07))

            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 32)).foregroundStyle(.white.opacity(0.1))
                Text(subtitle)
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.22))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
        }
        .background(bgCard, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }

    // MARK: - Font tab

    private var fontTab: some View {
        VStack(alignment: .leading, spacing: 20) {
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
                        .font(.system(size: 14))
                        .foregroundStyle(themeManager.current.primary.opacity(0.6))
                    Text("Font applies throughout the app: track titles, artist names, menus, and controls.")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.45))
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

        return Button { themeManager.selectFont(f) } label: {
            VStack(alignment: .leading, spacing: 12) {
                // Preview text
                Text(f.preview)
                    .font(f.font(18, .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Divider().background(Color.white.opacity(0.08))

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(f.label)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(selected ? accent : .white)
                        Text(fontSubtitle(f))
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    Spacer()
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(accent)
                    }
                }
            }
            .padding(14)
            .background(bgCard, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(selected ? accent : Color.white.opacity(0.06), lineWidth: selected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: themeManager.appFont)
    }

    private func fontSubtitle(_ f: AppFont) -> String {
        switch f {
        case .system:  return "SF Pro · system default"
        case .rounded: return "SF Rounded · soft edges"
        case .serif:   return "New York · editorial"
        case .mono:    return "SF Mono · pixel / retro"
        }
    }
}
