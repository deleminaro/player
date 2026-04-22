import SwiftUI
import UIKit

struct AppTheme: Identifiable, Equatable {
    let id: String
    let name: String
    let primary: Color
    let onPrimary: Color
    var swatches: [Color]  // 1 or 2 colors shown in the picker card
}

extension AppTheme {
    static let dark     = AppTheme(id:"dark",     name:"Dark",     primary:.white,                                                   onPrimary:.black,                                           swatches:[.white])
    static let amoled   = AppTheme(id:"amoled",   name:"AMOLED",   primary:Color(white:0.92),                                        onPrimary:.black,                                           swatches:[Color(white:0.92), Color(white:0.12)])
    static let midnight = AppTheme(id:"midnight", name:"Midnight", primary:Color(red:0.38,green:0.56,blue:1.0),   onPrimary:Color(red:0.05,green:0.14,blue:0.56), swatches:[Color(red:0.38,green:0.56,blue:1.0), Color(red:0.05,green:0.14,blue:0.56)])
    static let emerald  = AppTheme(id:"emerald",  name:"Emerald",  primary:Color(red:0.16,green:0.86,blue:0.50),  onPrimary:Color(red:0.03,green:0.40,blue:0.22), swatches:[Color(red:0.16,green:0.86,blue:0.50), Color(red:0.03,green:0.40,blue:0.22)])
    static let sunset   = AppTheme(id:"sunset",   name:"Sunset",   primary:Color(red:1.0, green:0.58,blue:0.18),  onPrimary:Color(red:0.55,green:0.12,blue:0.06), swatches:[Color(red:1.0,green:0.58,blue:0.18), Color(red:0.55,green:0.12,blue:0.06)])
    static let ocean    = AppTheme(id:"ocean",    name:"Ocean",    primary:Color(red:0.12,green:0.94,blue:0.84),  onPrimary:Color(red:0.02,green:0.48,blue:0.44), swatches:[Color(red:0.12,green:0.94,blue:0.84), Color(red:0.02,green:0.48,blue:0.44)])
    static let lavender = AppTheme(id:"lavender", name:"Lavender", primary:Color(red:0.753,green:0.757,blue:1.0), onPrimary:Color(red:0.063,green:0.0,blue:0.663),swatches:[Color(red:0.753,green:0.757,blue:1.0), Color(red:0.063,green:0.0,blue:0.663)])
    static let rose     = AppTheme(id:"rose",     name:"Rose",     primary:Color(red:1.0,green:0.46,blue:0.56),   onPrimary:Color(red:0.68,green:0.06,blue:0.24), swatches:[Color(red:1.0,green:0.46,blue:0.56), Color(red:0.68,green:0.06,blue:0.24)])
    static let amber    = AppTheme(id:"amber",    name:"Amber",    primary:Color(red:1.0,green:0.74,blue:0.12),   onPrimary:Color(red:0.54,green:0.26,blue:0.02), swatches:[Color(red:1.0,green:0.74,blue:0.12), Color(red:0.54,green:0.26,blue:0.02)])
    static let slate    = AppTheme(id:"slate",    name:"Slate",    primary:Color(red:0.44,green:0.64,blue:1.0),   onPrimary:Color(red:0.10,green:0.22,blue:0.56), swatches:[Color(red:0.44,green:0.64,blue:1.0), Color(red:0.10,green:0.22,blue:0.56)])
    static let light    = AppTheme(id:"light",    name:"Light",    primary:Color(white:0.88),                     onPrimary:.black,                                swatches:[Color(white:0.88)])
    static let sky      = AppTheme(id:"sky",      name:"Sky",      primary:Color(red:0.38,green:0.72,blue:1.0),   onPrimary:Color(red:0.08,green:0.28,blue:0.82), swatches:[Color(red:0.38,green:0.72,blue:1.0), Color(red:0.08,green:0.28,blue:0.82)])
    static let mint     = AppTheme(id:"mint",     name:"Mint",     primary:Color(red:0.22,green:0.90,blue:0.60),  onPrimary:Color(red:0.04,green:0.40,blue:0.24), swatches:[Color(red:0.22,green:0.90,blue:0.60), Color(red:0.04,green:0.40,blue:0.24)])
    static let violet   = AppTheme(id:"violet",   name:"Violet",   primary:Color(red:0.72,green:0.40,blue:1.0),   onPrimary:Color(red:0.28,green:0.04,blue:0.62), swatches:[Color(red:0.72,green:0.40,blue:1.0), Color(red:0.28,green:0.04,blue:0.62)])
    static let blossom  = AppTheme(id:"blossom",  name:"Blossom",  primary:Color(red:1.0,green:0.36,blue:0.38),   onPrimary:Color(red:0.62,green:0.04,blue:0.14), swatches:[Color(red:1.0,green:0.36,blue:0.38), Color(red:0.62,green:0.04,blue:0.14)])
    static let sand     = AppTheme(id:"sand",     name:"Sand",     primary:Color(red:1.0,green:0.74,blue:0.20),   onPrimary:Color(red:0.52,green:0.28,blue:0.02), swatches:[Color(red:1.0,green:0.74,blue:0.20), Color(red:0.52,green:0.28,blue:0.02)])
    static let aqua     = AppTheme(id:"aqua",     name:"Aqua",     primary:Color(red:0.14,green:0.88,blue:0.78),  onPrimary:Color(red:0.02,green:0.42,blue:0.38), swatches:[Color(red:0.14,green:0.88,blue:0.78), Color(red:0.02,green:0.42,blue:0.38)])

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

// MARK: - Slider type

enum SliderType: String, CaseIterable {
    case waveform1 = "waveform1"
    case waveform2 = "waveform2"
    case classic   = "classic"

    var label: String {
        switch self {
        case .waveform1: return "Waveform I"
        case .waveform2: return "Waveform II"
        case .classic:   return "Classic"
        }
    }
}

final class ThemeManager: ObservableObject {
    @Published private(set) var current:         AppTheme       = .dark
    @Published private(set) var sliderType:      SliderType     = .waveform1
    @Published private(set) var backgroundStyle: BackgroundStyle = .musicCover
    @Published private(set) var customWallpaper: UIImage?       = nil

    private let themeKey   = "mp_theme"
    private let sliderKey  = "mp_slider_type"
    private let bgStyleKey = "mp_bg_style"
    private var wallpaperURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("custom_wallpaper.jpg")
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
        if let url = wallpaperURL,
           let data = try? Data(contentsOf: url) {
            customWallpaper = UIImage(data: data)
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

    func saveCustomWallpaper(_ image: UIImage) {
        customWallpaper = image
        backgroundStyle = .customPhoto
        UserDefaults.standard.set(BackgroundStyle.customPhoto.rawValue, forKey: bgStyleKey)
        if let data = image.jpegData(compressionQuality: 0.85), let url = wallpaperURL {
            try? data.write(to: url)
        }
    }
}
