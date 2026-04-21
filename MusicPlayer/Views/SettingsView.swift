import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager

    private let bg      = Color(red: 0.075, green: 0.075, blue: 0.075)
    private let bgCard  = Color(red: 0.110, green: 0.110, blue: 0.110)
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("THEME")
                        .font(.system(size: 10, weight: .black)).kerning(2)
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(AppTheme.all) { theme in
                            ThemeCard(theme: theme,
                                      isSelected: themeManager.current.id == theme.id,
                                      bgCard: bgCard)
                                .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { themeManager.select(theme) } }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 120)
            }
            .background(bg.ignoresSafeArea())
            .navigationTitle("Interface")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(bg, for: .navigationBar)
            .preferredColorScheme(.dark)
        }
    }
}

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
