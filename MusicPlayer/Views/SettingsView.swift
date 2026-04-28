import SwiftUI
import PhotosUI

struct SettingsView: View {
    @EnvironmentObject var themeManager:   ThemeManager
    @EnvironmentObject var firebaseManager: FirebaseManager

    @AppStorage("mp_audio_quality")    private var audioQuality:      AudioQuality = .lossless
    @AppStorage("mp_caching_mode")     private var cachingMode:       CachingMode  = .memory
    @AppStorage("mp_show_notifs")      private var showNotifications: Bool         = true
    @AppStorage("mp_resume_track")     private var resumeLastTrack:   Bool         = true
    @AppStorage("mp_cache_listened")   private var cacheListened:     Bool         = true
    @AppStorage("mp_cache_playlists")  private var cachePlaylists:    Bool         = false

    @State private var showQualitySheet  = false
    @State private var showCachingSheet  = false
    @State private var showLogoutConfirm = false
    @State private var showNameEdit      = false
    @State private var editingName       = ""
    @State private var avatarItem: PhotosPickerItem?

    private var bg:     Color { themeManager.current.background }
    private var bgCard: Color { themeManager.current.card }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // ACCOUNT (shown when logged in)
                    if let user = firebaseManager.currentUser {
                        settingSection(title: "ACCOUNT") {
                            HStack(spacing: 16) {
                                // Avatar
                                PhotosPicker(selection: $avatarItem, matching: .images) {
                                    ZStack {
                                        if let img = user.avatarImage {
                                            Image(uiImage: img)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 56, height: 56)
                                                .clipShape(Circle())
                                        } else {
                                            Circle()
                                                .fill(themeManager.current.primary.opacity(0.15))
                                                .frame(width: 56, height: 56)
                                            Image(systemName: "person.fill")
                                                .font(.system(size: 22))
                                                .foregroundStyle(themeManager.current.primary)
                                        }
                                        // Edit badge
                                        Image(systemName: "pencil.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundStyle(.white)
                                            .background(Circle().fill(Color.black.opacity(0.5)).padding(-1))
                                            .offset(x: 18, y: 18)
                                    }
                                }
                                .buttonStyle(.plain)

                                // Name & username
                                VStack(alignment: .leading, spacing: 5) {
                                    Button {
                                        editingName = user.displayName
                                        showNameEdit = true
                                    } label: {
                                        HStack(spacing: 6) {
                                            Text(user.displayName.isEmpty ? "Set name" : user.displayName)
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundStyle(.white)
                                            Image(systemName: "pencil")
                                                .font(.system(size: 12))
                                                .foregroundStyle(.white.opacity(0.4))
                                        }
                                    }
                                    .buttonStyle(.plain)

                                    Text("@\(user.username)")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.white.opacity(0.4))

                                    if !user.email.isEmpty {
                                        Text(user.email)
                                            .font(.system(size: 12))
                                            .foregroundStyle(.white.opacity(0.3))
                                    }
                                }

                                Spacer()
                            }
                        }

                        // Log out button
                        Button { showLogoutConfirm = true } label: {
                            Text("Log Out")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(ScaleButtonStyle(scale: 0.96))
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }

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
                                    Text("Background, cover, slider & theme")
                                        .font(.system(size: 12)).foregroundStyle(.white.opacity(0.4))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.3))
                            }
                        }
                        .buttonStyle(.plain)
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
        // Sheets
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
        // Logout confirmation
        .confirmationDialog("Sign Out", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) { firebaseManager.logOut() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out?")
        }
        // Edit display name
        .alert("Display Name", isPresented: $showNameEdit) {
            TextField("Name", text: $editingName)
                .autocorrectionDisabled()
            Button("Save") {
                let trimmed = editingName.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                Task { try? await firebaseManager.updateDisplayName(trimmed) }
            }
            Button("Cancel", role: .cancel) {}
        }
        // Avatar photo picker
        .onChange(of: avatarItem) { _, newItem in
            guard let item = newItem else { return }
            Task {
                if let data  = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    try? await firebaseManager.updateAvatar(image)
                }
                avatarItem = nil
            }
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

            ForEach(CachingMode.allCases, id: \.rawValue) { m in
                let on = mode == m
                Button { mode = m } label: {
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

            Divider().background(Color.white.opacity(0.07)).padding(.horizontal, 20).padding(.vertical, 8)

            settingToggle("Cache listened tracks", value: $cacheListened)
            settingToggle("Cache playlist tracks", value: $cachePlaylists)

            Spacer()
        }
        .preferredColorScheme(.dark)
    }

    private func settingToggle(_ title: String, value: Binding<Bool>) -> some View {
        HStack {
            Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
            Spacer()
            Toggle("", isOn: value)
                .toggleStyle(SwitchToggleStyle(tint: themeManager.current.primary))
                .labelsHidden()
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
    }
}
