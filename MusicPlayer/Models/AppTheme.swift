import SwiftUI
import UIKit

struct AppTheme: Identifiable, Equatable {
    let id: String
    let name: String
    let primary: Color
    let onPrimary: Color
    let background: Color  // main screen fill
    let card: Color        // elevated surface / card fill
    var swatches: [Color]
}

private let _darkBg   = Color(red: 0.075, green: 0.075, blue: 0.075)
private let _darkCard = Color(red: 0.110, green: 0.110, blue: 0.110)

extension AppTheme {
    static let dark     = AppTheme(id:"dark",     name:"Dark",     primary:.white,                                                   onPrimary:.black,                                           background:_darkBg, card:_darkCard, swatches:[.white])
    static let amoled   = AppTheme(id:"amoled",   name:"AMOLED",   primary:.white,                                                   onPrimary:.black,                                           background:.black,  card:.black,            swatches:[.white])
    static let midnight = AppTheme(id:"midnight", name:"Midnight", primary:Color(red:0.38,green:0.56,blue:1.0),   onPrimary:Color(red:0.05,green:0.14,blue:0.56), background:_darkBg, card:_darkCard, swatches:[Color(red:0.38,green:0.56,blue:1.0), Color(red:0.05,green:0.14,blue:0.56)])
    static let emerald  = AppTheme(id:"emerald",  name:"Emerald",  primary:Color(red:0.16,green:0.86,blue:0.50),  onPrimary:Color(red:0.03,green:0.40,blue:0.22), background:_darkBg, card:_darkCard, swatches:[Color(red:0.16,green:0.86,blue:0.50), Color(red:0.03,green:0.40,blue:0.22)])
    static let sunset   = AppTheme(id:"sunset",   name:"Sunset",   primary:Color(red:1.0, green:0.58,blue:0.18),  onPrimary:Color(red:0.55,green:0.12,blue:0.06), background:_darkBg, card:_darkCard, swatches:[Color(red:1.0,green:0.58,blue:0.18), Color(red:0.55,green:0.12,blue:0.06)])
    static let ocean    = AppTheme(id:"ocean",    name:"Ocean",    primary:Color(red:0.12,green:0.94,blue:0.84),  onPrimary:Color(red:0.02,green:0.48,blue:0.44), background:_darkBg, card:_darkCard, swatches:[Color(red:0.12,green:0.94,blue:0.84), Color(red:0.02,green:0.48,blue:0.44)])
    static let lavender = AppTheme(id:"lavender", name:"Lavender", primary:Color(red:0.753,green:0.757,blue:1.0), onPrimary:Color(red:0.063,green:0.0,blue:0.663),background:_darkBg, card:_darkCard, swatches:[Color(red:0.753,green:0.757,blue:1.0), Color(red:0.063,green:0.0,blue:0.663)])
    static let rose     = AppTheme(id:"rose",     name:"Rose",     primary:Color(red:1.0,green:0.46,blue:0.56),   onPrimary:Color(red:0.68,green:0.06,blue:0.24), background:_darkBg, card:_darkCard, swatches:[Color(red:1.0,green:0.46,blue:0.56), Color(red:0.68,green:0.06,blue:0.24)])
    static let amber    = AppTheme(id:"amber",    name:"Amber",    primary:Color(red:1.0,green:0.74,blue:0.12),   onPrimary:Color(red:0.54,green:0.26,blue:0.02), background:_darkBg, card:_darkCard, swatches:[Color(red:1.0,green:0.74,blue:0.12), Color(red:0.54,green:0.26,blue:0.02)])
    static let slate    = AppTheme(id:"slate",    name:"Slate",    primary:Color(red:0.44,green:0.64,blue:1.0),   onPrimary:Color(red:0.10,green:0.22,blue:0.56), background:_darkBg, card:_darkCard, swatches:[Color(red:0.44,green:0.64,blue:1.0), Color(red:0.10,green:0.22,blue:0.56)])
    static let light    = AppTheme(id:"light",    name:"Light",    primary:Color(white:0.88),                     onPrimary:.black,                                background:_darkBg, card:_darkCard, swatches:[Color(white:0.88)])
    static let sky      = AppTheme(id:"sky",      name:"Sky",      primary:Color(red:0.38,green:0.72,blue:1.0),   onPrimary:Color(red:0.08,green:0.28,blue:0.82), background:_darkBg, card:_darkCard, swatches:[Color(red:0.38,green:0.72,blue:1.0), Color(red:0.08,green:0.28,blue:0.82)])
    static let mint     = AppTheme(id:"mint",     name:"Mint",     primary:Color(red:0.22,green:0.90,blue:0.60),  onPrimary:Color(red:0.04,green:0.40,blue:0.24), background:_darkBg, card:_darkCard, swatches:[Color(red:0.22,green:0.90,blue:0.60), Color(red:0.04,green:0.40,blue:0.24)])
    static let violet   = AppTheme(id:"violet",   name:"Violet",   primary:Color(red:0.72,green:0.40,blue:1.0),   onPrimary:Color(red:0.28,green:0.04,blue:0.62), background:_darkBg, card:_darkCard, swatches:[Color(red:0.72,green:0.40,blue:1.0), Color(red:0.28,green:0.04,blue:0.62)])
    static let blossom  = AppTheme(id:"blossom",  name:"Blossom",  primary:Color(red:1.0,green:0.36,blue:0.38),   onPrimary:Color(red:0.62,green:0.04,blue:0.14), background:_darkBg, card:_darkCard, swatches:[Color(red:1.0,green:0.36,blue:0.38), Color(red:0.62,green:0.04,blue:0.14)])
    static let sand     = AppTheme(id:"sand",     name:"Sand",     primary:Color(red:1.0,green:0.74,blue:0.20),   onPrimary:Color(red:0.52,green:0.28,blue:0.02), background:_darkBg, card:_darkCard, swatches:[Color(red:1.0,green:0.74,blue:0.20), Color(red:0.52,green:0.28,blue:0.02)])
    static let aqua     = AppTheme(id:"aqua",     name:"Aqua",     primary:Color(red:0.14,green:0.88,blue:0.78),  onPrimary:Color(red:0.02,green:0.42,blue:0.38), background:_darkBg, card:_darkCard, swatches:[Color(red:0.14,green:0.88,blue:0.78), Color(red:0.02,green:0.42,blue:0.38)])

    static let all: [AppTheme] = [dark, amoled, midnight, emerald, sunset, ocean, lavender, rose, amber, slate, light, sky, mint, violet, blossom, sand, aqua]
}

// MARK: - Audio quality

enum AudioQuality: String, CaseIterable {
    case low      = "low"
    case medium   = "medium"
    case high     = "high"
    case lossless = "lossless"

    var label: String {
        switch self {
        case .low:      return "Low"
        case .medium:   return "Medium"
        case .high:     return "High"
        case .lossless: return "Lossless"
        }
    }
    var subtitle: String {
        switch self {
        case .low:      return "192 kbps"
        case .medium:   return "256 kbps"
        case .high:     return "320 kbps"
        case .lossless: return "FLAC / LOSSLESS"
        }
    }
    var icon: String {
        switch self {
        case .low:      return "radio"
        case .medium:   return "headphones"
        case .high:     return "opticaldisc"
        case .lossless: return "waveform"
        }
    }

}

// MARK: - Caching mode

enum CachingMode: String, CaseIterable {
    case off    = "off"
    case memory = "memory"
    case device = "device"

    var label: String {
        switch self {
        case .off:    return "Off"
        case .memory: return "In memory"
        case .device: return "On device"
        }
    }
    var icon: String {
        switch self {
        case .off:    return "nosign"
        case .memory: return "cylinder.split.1x2"
        case .device: return "internaldrive"
        }
    }
}

// MARK: - Background style

enum BackgroundStyle: String {
    case musicCover  = "musicCover"
    case customPhoto = "customPhoto"
}

// MARK: - Cover style

enum CoverStyle: String {
    case albumArt    = "albumArt"
    case customPhoto = "customPhoto"
    case hidden      = "hidden"
}

// MARK: - Slider type

enum SliderType: String, CaseIterable {
    case waveform2 = "waveform2"
    case classic   = "classic"
    case glimmer   = "glimmer"

    var label: String {
        switch self {
        case .waveform2: return "Waveform"
        case .classic:   return "Classic"
        case .glimmer:   return "Glimmer"
        }
    }
}

// MARK: - App font

enum AppFont: String, CaseIterable {
    case system     = "system"
    case rounded    = "rounded"
    case serif      = "serif"
    case mono       = "mono"
    case minecraft  = "minecraft"

    var label: String {
        switch self {
        case .system:    return "Default"
        case .rounded:   return "Rounded"
        case .serif:     return "Serif"
        case .mono:      return "Pixel"
        case .minecraft: return "Monocraft"
        }
    }

    var icon: String {
        switch self {
        case .system:    return "textformat"
        case .rounded:   return "textformat.alt"
        case .serif:     return "f.cursive"
        case .mono:      return "chevron.left.forwardslash.chevron.right"
        case .minecraft: return "square.grid.3x3.fill"
        }
    }

    var preview: String { "The quick fox" }

    var fontDesign: Font.Design {
        switch self {
        case .system:    return .default
        case .rounded:   return .rounded
        case .serif:     return .serif
        case .mono:      return .monospaced
        case .minecraft: return .monospaced
        }
    }

    // Auto-discovers bold then regular PostScript names from registered fonts at first use.
    fileprivate static let resolvedFontName: String? = {
        let candidates = [
            "Monocraft-Bold", "Monocraft Bold", "Monocraft-SemiBold",
            "Monocraft", "Monocraft-Regular",
            "Minecraft-Bold", "Minecraft", "Minecraft-Regular"
        ]
        for name in candidates {
            if UIFont(name: name, size: 14) != nil { return name }
        }
        for family in UIFont.familyNames {
            let lower = family.lowercased()
            if lower.contains("monocraft") || lower.contains("minecraft") {
                let names = UIFont.fontNames(forFamilyName: family)
                return names.first(where: { $0.lowercased().contains("bold") }) ?? names.first ?? family
            }
        }
        return nil
    }()

    // Global reference — updated on main thread whenever ThemeManager changes the font.
    nonisolated(unsafe) static var current: AppFont = .system

    func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        switch self {
        case .system:    return .system(size: size, weight: weight)
        case .rounded:   return .system(size: size, weight: weight, design: .rounded)
        case .serif:     return .system(size: size, weight: weight, design: .serif)
        case .mono:      return .system(size: size, weight: weight, design: .monospaced)
        case .minecraft:
            if let name = AppFont.resolvedFontName {
                return .custom(name, size: size)
            }
            return .system(size: size, weight: weight, design: .monospaced)
        }
    }
}

// Convenience — use anywhere without needing an environment object.
extension Font {
    static func app(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        AppFont.current.font(size, weight)
    }
}

final class ThemeManager: ObservableObject {
    @Published private(set) var current:         AppTheme       = .dark
    @Published private(set) var sliderType:      SliderType     = .waveform2
    @Published private(set) var backgroundStyle: BackgroundStyle = .musicCover
    @Published private(set) var coverStyle:      CoverStyle     = .albumArt
    @Published private(set) var appFont:         AppFont        = .system
    @Published private(set) var customWallpaper: UIImage?       = nil
    @Published private(set) var customCoverImage: UIImage?      = nil

    private let themeKey      = "mp_theme"
    private let sliderKey     = "mp_slider_type"
    private let bgStyleKey    = "mp_bg_style"
    private let coverStyleKey = "mp_cover_style"
    private let fontKey       = "mp_app_font"

    func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        appFont.font(size, weight)
    }

    private var wallpaperURL: URL? { docURL("custom_wallpaper.jpg") }
    private var coverImageURL: URL? { docURL("custom_cover.jpg") }

    private func docURL(_ name: String) -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(name)
    }

    init() {
        if let id = UserDefaults.standard.string(forKey: themeKey),
           let saved = AppTheme.all.first(where: { $0.id == id }) {
            current = saved
        }
        if let raw = UserDefaults.standard.string(forKey: sliderKey),
           let st = SliderType(rawValue: raw) {
            sliderType = st
        }
        if let raw = UserDefaults.standard.string(forKey: bgStyleKey),
           let style = BackgroundStyle(rawValue: raw) {
            backgroundStyle = style
        }
        if let raw = UserDefaults.standard.string(forKey: coverStyleKey),
           let style = CoverStyle(rawValue: raw) {
            coverStyle = style
        }
        if let raw = UserDefaults.standard.string(forKey: fontKey),
           let f = AppFont(rawValue: raw) {
            appFont = f
            AppFont.current = f
        }
        let fontInfo = AppFont.resolvedFontName.map { "Monocraft → \"\($0)\"" } ?? "Monocraft → NOT FOUND"
        AppLogger.shared.log(fontInfo, category: "Font")
        // Log every registered non-system font family so we can find the correct PostScript name
        let systemFamilies = Set(["Arial", "Helvetica", "Times New Roman", "Courier", "Georgia",
                                   "Verdana", "Trebuchet MS", "Impact", "Palatino", "Didot",
                                   "American Typewriter", "Futura", "Gill Sans", "Optima",
                                   "Baskerville", "Copperplate", ".SF", "SF Pro", "SF Compact",
                                   "New York", "Menlo", "Monaco", "Courier New", "Symbol",
                                   "Apple SD", "PingFang", "Hiragino", "Noto"])
        for family in UIFont.familyNames.sorted() {
            let isSystem = systemFamilies.contains(where: { family.hasPrefix($0) }) || family.hasPrefix(".")
            if !isSystem {
                let names = UIFont.fontNames(forFamilyName: family).joined(separator: ", ")
                AppLogger.shared.log("family:\"\(family)\" → [\(names)]", category: "Font")
            }
        }
        applyFontAppearance()
        if let url = wallpaperURL, let data = try? Data(contentsOf: url) {
            customWallpaper = UIImage(data: data)
        }
        if let url = coverImageURL, let data = try? Data(contentsOf: url) {
            customCoverImage = UIImage(data: data)
        }
    }

    func select(_ theme: AppTheme) {
        current = theme
        UserDefaults.standard.set(theme.id, forKey: themeKey)
    }

    func selectSlider(_ type: SliderType) {
        sliderType = type
        UserDefaults.standard.set(type.rawValue, forKey: sliderKey)
    }

    func selectBackground(_ style: BackgroundStyle) {
        backgroundStyle = style
        UserDefaults.standard.set(style.rawValue, forKey: bgStyleKey)
    }

    func selectCover(_ style: CoverStyle) {
        coverStyle = style
        UserDefaults.standard.set(style.rawValue, forKey: coverStyleKey)
    }

    func selectFont(_ f: AppFont) {
        appFont = f
        AppFont.current = f
        UserDefaults.standard.set(f.rawValue, forKey: fontKey)
        applyFontAppearance(f)
    }

    // Applies custom font to UINavigationBar and UITabBar system UI elements.
    func applyFontAppearance(_ f: AppFont? = nil) {
        let active = f ?? appFont
        guard active == .minecraft, let name = AppFont.resolvedFontName else {
            // Reset to system defaults
            let nav = UINavigationBarAppearance()
            nav.configureWithTransparentBackground()
            UINavigationBar.appearance().standardAppearance   = nav
            UINavigationBar.appearance().scrollEdgeAppearance = nav
            UINavigationBar.appearance().compactAppearance    = nav
            return
        }
        let titleSize: CGFloat  = 17
        let largeSize: CGFloat  = 32
        let tabSize:   CGFloat  = 10
        let titleFont    = UIFont(name: name, size: titleSize) ?? .systemFont(ofSize: titleSize, weight: .semibold)
        let largeTitleFont = UIFont(name: name, size: largeSize) ?? .boldSystemFont(ofSize: largeSize)
        let tabFont      = UIFont(name: name, size: tabSize)   ?? .systemFont(ofSize: tabSize)

        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.titleTextAttributes      = [.font: titleFont,      .foregroundColor: UIColor.white]
        nav.largeTitleTextAttributes = [.font: largeTitleFont, .foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance   = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance    = nav

        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.titleTextAttributes   = [.font: tabFont]
        itemAppearance.selected.titleTextAttributes = [.font: tabFont]
        let tab = UITabBarAppearance()
        tab.configureWithDefaultBackground()
        tab.stackedLayoutAppearance       = itemAppearance
        tab.inlineLayoutAppearance        = itemAppearance
        tab.compactInlineLayoutAppearance = itemAppearance
        UITabBar.appearance().standardAppearance   = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }

    func saveCustomWallpaper(_ image: UIImage) {
        customWallpaper = image
        backgroundStyle = .customPhoto
        UserDefaults.standard.set(BackgroundStyle.customPhoto.rawValue, forKey: bgStyleKey)
        if let data = image.jpegData(compressionQuality: 0.85), let url = wallpaperURL {
            try? data.write(to: url)
        }
    }

    func saveCustomCoverImage(_ image: UIImage) {
        customCoverImage = image
        coverStyle = .customPhoto
        UserDefaults.standard.set(CoverStyle.customPhoto.rawValue, forKey: coverStyleKey)
        if let data = image.jpegData(compressionQuality: 0.85), let url = coverImageURL {
            try? data.write(to: url)
        }
    }

    func deleteCustomCoverImage() {
        customCoverImage = nil
        coverStyle = .albumArt
        UserDefaults.standard.set(CoverStyle.albumArt.rawValue, forKey: coverStyleKey)
        if let url = coverImageURL { try? FileManager.default.removeItem(at: url) }
    }
}
