import SwiftUI

struct SCImportView: View {
    @EnvironmentObject var playerVM:    PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    @State private var profileInput = ""
    @State private var phase: Phase  = .idle
    @FocusState private var focused: Bool

    private let scOrange = Color(red: 1.0, green: 0.34, blue: 0.0)

    private enum Phase: Equatable {
        case idle
        case loading
        case done(Int)
        case error(String)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 36, height: 4)
                .padding(.top, 14)

            // Icon + header
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(scOrange.opacity(0.14))
                        .frame(width: 68, height: 68)
                    Image(systemName: "square.and.arrow.down.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(scOrange)
                }
                .padding(.top, 24)

                Text("Import SoundCloud Likes")
                    .font(.app(20, .bold))
                    .foregroundStyle(.white)

                Text("Enter your SoundCloud username and we'll import all your liked tracks into the Library.")
                    .font(.app(13))
                    .foregroundStyle(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.bottom, 28)

            // Input
            HStack(spacing: 12) {
                Image(systemName: "at")
                    .font(.app(15))
                    .foregroundStyle(.white.opacity(0.35))
                    .frame(width: 20)

                TextField("username", text: $profileInput)
                    .foregroundStyle(.white)
                    .tint(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .focused($focused)
                    .submitLabel(.go)
                    .onSubmit { startImport() }

                if !profileInput.isEmpty {
                    Button { profileInput = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.28))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 15)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
            .padding(.horizontal, 24)

            // Status
            statusView
                .frame(height: 44)
                .animation(.spring(duration: 0.28), value: phase)

            Spacer()

            // CTA
            Button(action: primaryAction) {
                Text(primaryLabel)
                    .font(.app(16, .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(primaryEnabled ? .white : Color.white.opacity(0.35),
                                in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.96))
            .disabled(!primaryEnabled)
            .padding(.horizontal, 24)

            Button("Skip for now") { dismiss() }
                .font(.app(13))
                .foregroundStyle(.white.opacity(0.3))
                .padding(.top, 14)
                .padding(.bottom, 48)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { focused = true }
        }
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var statusView: some View {
        switch phase {
        case .idle:
            EmptyView()
        case .loading:
            HStack(spacing: 10) {
                ProgressView().tint(scOrange)
                Text("Fetching likes…")
                    .font(.app(13))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.top, 16)
        case .done(let count):
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(count == 0
                     ? "No new tracks found."
                     : "\(count) track\(count == 1 ? "" : "s") added to Library.")
                    .font(.app(14, .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.top, 16)
            .transition(.scale(scale: 0.85).combined(with: .opacity))
        case .error(let msg):
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(msg)
                    .font(.app(13))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)
            }
            .padding(.top, 16)
            .transition(.opacity)
        }
    }

    // MARK: - Helpers

    private var primaryLabel: String {
        switch phase {
        case .loading:    return "Importing…"
        case .done:       return "Done"
        default:          return "Import Likes"
        }
    }

    private var primaryEnabled: Bool {
        switch phase {
        case .loading:    return false
        case .done:       return true
        default:          return !profileInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func primaryAction() {
        if case .done = phase { dismiss(); return }
        startImport()
    }

    private func startImport() {
        let input = profileInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        focused = false
        phase = .loading

        Task {
            do {
                let sc = SoundCloudService.shared
                let user   = try await sc.resolveUser(permalink: input)
                let tracks = try await sc.fetchUserLikes(userID: user.id)
                let added  = await MainActor.run { playerVM.importSCLikes(tracks) }
                await MainActor.run {
                    withAnimation { phase = .done(added) }
                }
            } catch let err as SoundCloudService.SCError {
                let msg: String
                switch err {
                case .badResponse(404):
                    msg = "Profile not found. Check your username."
                default:
                    msg = err.errorDescription ?? "Something went wrong."
                }
                await MainActor.run { withAnimation { phase = .error(msg) } }
            } catch {
                await MainActor.run { withAnimation { phase = .error(error.localizedDescription) } }
            }
        }
    }
}
