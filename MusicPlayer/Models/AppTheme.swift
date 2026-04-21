import SwiftUI

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

final class ThemeManager: ObservableObject {
    @Published private(set) var current: AppTheme = .dark
    private let key = "mp_theme"

    init() {
        if let id = UserDefaults.standard.string(forKey: key),
           let saved = AppTheme.all.first(where: { $0.id == id }) {
            current = saved
        }
    }

    func select(_ theme: AppTheme) {
        current = theme
        UserDefaults.standard.set(theme.id, forKey: key)
    }
}
