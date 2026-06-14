import SwiftUI

struct SleepTimerSheet: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    private let options: [(label: String, mode: SleepTimerMode)] = [
        ("5 minutes",  .duration(5 * 60)),
        ("15 minutes", .duration(15 * 60)),
        ("30 minutes", .duration(30 * 60)),
        ("45 minutes", .duration(45 * 60)),
        ("1 hour",     .duration(60 * 60)),
        ("End of track", .endOfTrack),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Sleep Timer")
                    .font(.app(17, .bold))
                    .foregroundStyle(.white)
                Spacer()
                if playerVM.sleepTimerMode != .off {
                    Button("Cancel") {
                        playerVM.setSleepTimer(.off)
                        dismiss()
                    }
                    .font(.app(14, .semibold))
                    .foregroundStyle(themeManager.current.primary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 14)

            Divider().background(Color.white.opacity(0.07))

            ScrollView(showsIndicators: false) {
                VStack(spacing: 2) {
                    ForEach(options, id: \.label) { opt in
                        let active = playerVM.sleepTimerMode == opt.mode
                        Button {
                            playerVM.setSleepTimer(active ? .off : opt.mode)
                            dismiss()
                        } label: {
                            HStack {
                                Text(opt.label)
                                    .font(.app(15, active ? .semibold : .regular))
                                    .foregroundStyle(active ? themeManager.current.primary : .white)
                                Spacer()
                                if active {
                                    Image(systemName: "checkmark")
                                        .font(.app(13, .semibold))
                                        .foregroundStyle(themeManager.current.primary)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 4)
            }
        }
        .preferredColorScheme(.dark)
    }
}
