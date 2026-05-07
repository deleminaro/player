import SwiftUI

struct SpotifyOnboardingSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var spotify = SpotifyService.shared

    @State private var isConnecting = false
    @State private var error: String?

    private var accent: Color { themeManager.current.primary }
    private let spotifyGreen = Color(red: 0.11, green: 0.73, blue: 0.33)

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 36, height: 4)
                .padding(.top, 14)

            Spacer()

            // Icon stack
            ZStack {
                Circle()
                    .fill(spotifyGreen.opacity(0.15))
                    .frame(width: 110, height: 110)
                Circle()
                    .fill(spotifyGreen.opacity(0.08))
                    .frame(width: 150, height: 150)
                Text("S")
                    .font(.system(size: 52, weight: .black))
                    .foregroundStyle(spotifyGreen)
            }
            .padding(.bottom, 28)

            Text("Connect Spotify")
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(.white)
            Text("Search and play Spotify tracks\ndirectly inside POSTOR.")
                .font(themeManager.font(15))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.top, 8)
                .padding(.horizontal, 40)

            // Feature bullets
            VStack(alignment: .leading, spacing: 12) {
                featureBullet(icon: "magnifyingglass", text: "Search the full Spotify catalogue")
                featureBullet(icon: "play.fill",       text: "Stream via SoundCloud — full tracks")
                featureBullet(icon: "heart.fill",      text: "Like and save Spotify tracks to your library")
            }
            .padding(.top, 32)
            .padding(.horizontal, 36)

            Spacer()

            VStack(spacing: 12) {
                if let error {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(.red.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Button {
                    isConnecting = true
                    error = nil
                    Task {
                        do {
                            try await SpotifyService.shared.startAuth()
                            dismiss()
                        } catch SpotifyError.authCancelled {
                            // user cancelled — no error shown
                        } catch {
                            self.error = error.localizedDescription
                        }
                        isConnecting = false
                    }
                } label: {
                    HStack(spacing: 10) {
                        if isConnecting {
                            ProgressView().tint(.black).scaleEffect(0.85)
                        } else {
                            Text("S").font(.system(size: 16, weight: .black)).foregroundStyle(.black)
                        }
                        Text(isConnecting ? "Connecting…" : "Connect Spotify")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.black)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(spotifyGreen, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(ScaleButtonStyle(scale: 0.97))
                .disabled(isConnecting)
                .padding(.horizontal, 24)

                Button { dismiss() } label: {
                    Text("Not now")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .padding(.bottom, 8)
            }
            .padding(.bottom, 24)
        }
        .preferredColorScheme(.dark)
        .background(Color(red: 0.07, green: 0.07, blue: 0.07))
    }

    private func featureBullet(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(spotifyGreen)
                .frame(width: 22)
            Text(text)
                .font(themeManager.font(14))
                .foregroundStyle(.white.opacity(0.75))
        }
    }
}
