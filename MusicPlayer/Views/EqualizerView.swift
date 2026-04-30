import SwiftUI

struct EqualizerView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    private let bandNames = ["BASS", "LOW\nMID", "MID", "HIGH\nMID", "TREBLE"]
    private var bg:       Color { themeManager.current.background }

    @State private var gains: [Float] = [0, 0, 0, 0, 0]

    private let presets: [(String, [Float])] = [
        ("FLAT",    [ 0,  0,  0,  0,  0]),
        ("BASS+",   [ 7,  4,  0, -1, -2]),
        ("TREBLE+", [-2,  0,  0,  4,  7]),
        ("VOCAL",   [-3,  0,  5,  4, -1]),
        ("DANCE",   [ 5,  3, -2,  2,  4]),
        ("SLOWED",  [ 3,  2,  0, -2, -3]),
    ]

    private var isSpotifyPremium: Bool {
        playerVM.currentTrack?.source == .spotify &&
        playerVM.currentTrack?.spotifyURI != nil &&
        SpotifyService.shared.currentAccessToken != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("EQUALIZER")
                    .font(.system(size: 14, weight: .black)).kerning(2).foregroundStyle(.white)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(8)
                        .background(Color.white.opacity(0.07), in: Circle())
                }
            }
            .padding(.horizontal, 24).padding(.top, 24)

            if isSpotifyPremium {
                HStack(spacing: 10) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 13))
                    Text("EQ and speed do not apply to Spotify Premium tracks — audio is rendered by the Spotify app.")
                        .font(.system(size: 11))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(Color(red: 0.11, green: 0.73, blue: 0.33).opacity(0.9))
                .padding(.horizontal, 20).padding(.vertical, 10)
                .background(Color(red: 0.11, green: 0.73, blue: 0.33).opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 24).padding(.top, 16)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(presets, id: \.0) { name, pg in
                        let active = gains == pg
                        Button {
                            withAnimation(.spring(response: 0.3)) { gains = pg }
                            for (i, g) in pg.enumerated() { playerVM.setEQGain(g, band: i) }
                        } label: {
                            Text(name)
                                .font(.system(size: 10, weight: .black)).kerning(1)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(active ? themeManager.current.primary : Color.white.opacity(0.08), in: Capsule())
                                .foregroundStyle(active ? themeManager.current.onPrimary : Color.white.opacity(0.7))
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.top, 20)

            HStack(alignment: .center, spacing: 0) {
                ForEach(0..<5, id: \.self) { i in
                    VStack(spacing: 10) {
                        Text("\(gains[i] >= 0 ? "+" : "")\(Int(gains[i]))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(gains[i] != 0 ? themeManager.current.primary : Color.white.opacity(0.3))
                            .frame(width: 36)

                        Slider(
                            value: Binding(
                                get: { Double(gains[i]) },
                                set: { gains[i] = Float($0); playerVM.setEQGain(Float($0), band: i) }
                            ),
                            in: -12...12
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 110)
                        .frame(width: 44, height: 110)
                        .tint(themeManager.current.primary)

                        Text(bandNames[i])
                            .font(.system(size: 8, weight: .black)).kerning(0.5)
                            .foregroundStyle(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                            .frame(width: 44)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 8).padding(.top, 24).padding(.bottom, 32)
        }
        .background(bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .presentationDetents([.height(390)])
        .presentationBackground(bg)
        .onAppear { gains = playerVM.audio.eqGains }
    }
}
