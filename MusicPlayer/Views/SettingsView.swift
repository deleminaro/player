import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager

    @AppStorage("mp_audio_quality")    private var audioQuality:      AudioQuality = .lossless
    @AppStorage("mp_caching_mode")     private var cachingMode:       CachingMode  = .memory
    @AppStorage("mp_show_notifs")      private var showNotifications: Bool         = true
    @AppStorage("mp_resume_track")     private var resumeLastTrack:   Bool         = true
    @AppStorage("mp_cache_listened")   private var cacheListened:     Bool         = true
    @AppStorage("mp_cache_playlists")  private var cachePlaylists:    Bool         = false

    @State private var showQualitySheet = false
    @State private var showCachingSheet = false

    private var bg:     Color { themeManager.current.background }
    private var bgCard: Color { themeManager.current.card }
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // GENERAL
                    settingSection(title: "GENERAL") {
                        VStack(spacing: 0) {
                            settingToggle("Last track will resume after restart",
                                          subtitle: "Restore playback on app launch",
                                          value: $resumeLastTrack)
                            Divider().background(Color.white.opacity(0.07)).padding(.vertical, 4)
                            settingToggle("Show notifications",
                                          subtitle: "In-app popups and alerts",
                                          value: $showNotifications)
                        }
                    }

                    // DEBUG
                    settingSection(title: "DEBUG") {
                        ShareLink(item: debugLogText) {
                            HStack(spacing: 14) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Share debug log")
                                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                                    Text("Send audio playback log for issue diagnosis")
                                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
                                }
                                Spacer()
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.35))
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    // ADDITIONAL
                    settingSection(title: "ADDITIONAL") {
                        VStack(spacing: 0) {
                            // Audio quality
                            Button { showQualitySheet = true } label: {
                                HStack(spacing: 14) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Audio quality")
                                            .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                                        Text(audioQuality.subtitle.uppercased())
                                            .font(.system(size: 11, weight: .bold)).kerning(0.5)
                                            .foregroundStyle(.white.opacity(0.4))
                                    }
                                    Spacer()
                                    Image(systemName: "waveform")
                                        .font(.system(size: 20)).foregroundStyle(.white.opacity(0.35))
                                }
                            }
                            .buttonStyle(.plain)

                            Divider().background(Color.white.opacity(0.07)).padding(.vertical, 14)

                            // Caching
                            Button { showCachingSheet = true } label: {
                                HStack(spacing: 14) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Caching")
                                            .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                                        Text(cachingMode.label)
                                            .font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
                                    }
                                    Spacer()
                                    Image(systemName: cachingMode.icon)
                                        .font(.system(size: 20)).foregroundStyle(.white.opacity(0.35))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // CUSTOMIZATION
                    settingSection(title: "CUSTOMIZATION") {
                        VStack(spacing: 14) {
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

                            Divider().background(Color.white.opacity(0.07))

                            Text("THEME")
                                .font(.system(size: 9, weight: .black)).kerning(1.5)
                                .foregroundStyle(.white.opacity(0.35))
                                .frame(maxWidth: .infinity, alignment: .leading)

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
                }
                .padding(.bottom, 120)
            }
            .background(bg.ignoresSafeArea())
            .navigationTitle("General")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showQualitySheet) {
            AudioQualitySheet(selected: $audioQuality)
                .environmentObject(themeManager)
                .presentationDetents([.fraction(0.58)])
                .presentationBackground(bgCard)
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showCachingSheet) {
            CachingSheet(mode: $cachingMode, cacheListened: $cacheListened, cachePlaylists: $cachePlaylists)
                .environmentObject(themeManager)
                .presentationDetents([.medium])
                .presentationBackground(bgCard)
                .presentationCornerRadius(28)
        }
    }

    private var debugLogText: String {
        """
        POSTOR Debug Log — \(Date())
        Audio Quality : \(audioQuality.label) (\(audioQuality.subtitle))
        Caching Mode  : \(cachingMode.label)
        Theme         : \(themeManager.current.name)
        Slider Type   : \(themeManager.sliderType.label)
        Background    : \(themeManager.backgroundStyle.rawValue)
        """
    }
}

// MARK: - Section helpers

private extension SettingsView {
    @ViewBuilder
    func settingSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
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

    @ViewBuilder
    func settingToggle(_ title: String, subtitle: String, value: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                Text(subtitle).font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
            }
            Spacer()
            Toggle("", isOn: value)
                .toggleStyle(SwitchToggleStyle(tint: themeManager.current.primary))
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Audio quality sheet

private struct AudioQualitySheet: View {
    @Binding var selected: AudioQuality
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(Color.white.opacity(0.25)).frame(width: 36, height: 4)
                .padding(.top, 12).padding(.bottom, 16)

            ForEach(AudioQuality.allCases, id: \.rawValue) { q in
                let on = selected == q
                Button {
                    selected = q
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { dismiss() }
                } label: {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(on ? Color.white.opacity(0.18) : Color.white.opacity(0.07))
                                .frame(width: 48, height: 48)
                            Image(systemName: q.icon)
                                .font(.system(size: 20, weight: .regular))
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(q.label).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                            Text(q.subtitle).font(.system(size: 12)).foregroundStyle(.white.opacity(0.4))
                        }
                        Spacer()
                        if on {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 20).padding(.vertical, 14)
                    .background(on ? Color.white.opacity(0.06) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 12).padding(.vertical, 3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(on ? Color.white.opacity(0.25) : Color.clear, lineWidth: 1)
                            .padding(.horizontal, 12).padding(.vertical, 3)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Caching sheet

private struct CachingSheet: View {
    @Binding var mode:           CachingMode
    @Binding var cacheListened:  Bool
    @Binding var cachePlaylists: Bool
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(Color.white.opacity(0.25)).frame(width: 36, height: 4)
                .padding(.top, 12).padding(.bottom, 16)

            // Mode options
            ForEach(CachingMode.allCases, id: \.rawValue) { m in
                let on = mode == m
                Button {
                    mode = m
                } label: {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(on ? Color.white.opacity(0.18) : Color.white.opacity(0.07))
                                .frame(width: 48, height: 48)
                            Image(systemName: m.icon)
                                .font(.system(size: 20, weight: .regular))
                                .foregroundStyle(.white)
                        }
                        Text(m.label).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                        Spacer()
                        if on {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 20).padding(.vertical, 14)
                    .background(on ? Color.white.opacity(0.06) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 12).padding(.vertical, 3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(on ? Color.white.opacity(0.25) : Color.clear, lineWidth: 1)
                            .padding(.horizontal, 12).padding(.vertical, 3)
                    )
                }
                .buttonStyle(.plain)
            }

            // Cache-target grid (shown when not Off)
            if mode != .off {
                Divider().background(Color.white.opacity(0.07)).padding(.horizontal, 20).padding(.vertical, 14)

                HStack(spacing: 12) {
                    cacheTargetCard("Listened", subtitle: "Auto-cache tracks you play",
                                    icon: "play.fill", on: $cacheListened)
                    cacheTargetCard("Playlists", subtitle: "Auto-cache tracks added to playlists",
                                    icon: "music.note.list", on: $cachePlaylists)
                }
                .padding(.horizontal, 16)
            }

            Spacer()
        }
        .preferredColorScheme(.dark)
    }

    private func cacheTargetCard(_ title: String, subtitle: String, icon: String, on: Binding<Bool>) -> some View {
        Button { on.wrappedValue.toggle() } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(.white.opacity(0.7))
                Text(title)
                    .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(on.wrappedValue ? Color.white.opacity(0.3) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
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
            sliderPreview.frame(height: 32)
            Text(type.label)
                .font(.custom("Courier", size: 11)).bold()
                .foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 10).padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(bgCard, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(isSelected ? accent : Color.clear, lineWidth: 2))
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
                let step = size.width / CGFloat(bars.count); let barW = max(1.5, step * 0.72)
                for (i, h) in bars.enumerated() {
                    let rect = CGRect(x: CGFloat(i)*step+(step-barW)/2, y: (size.height-h*size.height)/2, width: barW, height: h*size.height)
                    ctx.fill(Path(roundedRect: rect, cornerRadius: barW/2), with: .color(Double(i)/Double(bars.count) < fill ? accent : Color.white.opacity(0.22)))
                }
            }
        case .waveform2:
            Canvas { ctx, size in
                var rng = 54321 &* 1664525 &+ 1013904223
                let bars: [CGFloat] = (0..<28).map { _ in rng = rng &* 1664525 &+ 1013904223; return 0.2 + CGFloat((rng >> 16) & 0xFFFF) / 65535.0 * 0.8 }
                let step = size.width / CGFloat(bars.count); let barW = max(1.5, step * 0.65); let cy = size.height / 2
                for (i, h) in bars.enumerated() {
                    let halfH = h * cy * 0.9
                    let rect = CGRect(x: CGFloat(i)*step+(step-barW)/2, y: cy-halfH, width: barW, height: halfH*2)
                    ctx.fill(Path(roundedRect: rect, cornerRadius: barW/2), with: .color(Double(i)/Double(bars.count) < fill ? accent : Color.white.opacity(0.22)))
                }
            }
        case .classic:
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.15)).frame(height: 5)
                    Capsule().fill(accent).frame(width: geo.size.width * fill, height: 5)
                }.frame(maxHeight: .infinity, alignment: .center)
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
            RoundedRectangle(cornerRadius: 16).fill(bgCard)
            if isSelected { RoundedRectangle(cornerRadius: 16).stroke(.white, lineWidth: 2) }
            VStack {
                HStack(alignment: .top) {
                    HStack(spacing: 5) {
                        ForEach(theme.swatches.indices, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 6).fill(theme.swatches[i]).frame(width: 22, height: 22)
                        }
                    }
                    Spacer()
                    if isSelected { Circle().fill(.white).frame(width: 14, height: 14) }
                }.padding(12)
                Spacer()
            }
            Text(theme.name).font(.custom("Courier", size: 12)).bold().foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.bottom, 10)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
