import SwiftUI
import PhotosUI

struct SettingsView: View {
    @EnvironmentObject var themeManager:    ThemeManager
    @EnvironmentObject var firebaseManager: FirebaseManager

    @AppStorage("mp_caching_mode")    private var cachingMode:       CachingMode  = .memory
    @AppStorage("mp_resume_track")    private var resumeLastTrack:   Bool         = true
    @AppStorage("mp_cache_listened")  private var cacheListened:     Bool         = true
    @AppStorage("mp_cache_playlists") private var cachePlaylists:    Bool         = false

    @StateObject private var dm = DownloadManager.shared
    @State private var showCachingSheet       = false
    @State private var showLogoutConfirm      = false
    @State private var showNameEdit           = false
    @State private var showClearDownloads     = false
    @State private var editingName            = ""
    @State private var avatarItem: PhotosPickerItem?

    private var bg:     Color { themeManager.current.background }
    private var card:   Color { themeManager.current.card }
    private var accent: Color { themeManager.current.primary }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    if let user = firebaseManager.currentUser {
                        profileCard(user)
                    }

                    settingsGroup("AUDIO") {
                        HStack(spacing: 14) {
                            iconBox("waveform", bg: Color.blue.opacity(0.2), fg: .blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Audio Quality")
                                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                                Text("Always Lossless FLAC")
                                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(.blue.opacity(0.7))
                            }
                            Spacer()
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.2))
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        rowDivider()
                        settingsRow(icon: cachingMode.icon, iconBg: Color.purple.opacity(0.2), iconFg: .purple,
                                    title: "Caching", subtitle: cachingMode.label) {
                            showCachingSheet = true
                        }
                    }

                    settingsGroup("PLAYBACK") {
                        toggleRow(icon: "arrow.counterclockwise", iconBg: Color.orange.opacity(0.2), iconFg: .orange,
                                  title: "Resume on launch", value: $resumeLastTrack)
                    }

                    settingsGroup("APPEARANCE") {
                        NavigationLink {
                            CustomizationView().environmentObject(themeManager)
                        } label: {
                            HStack(spacing: 14) {
                                iconBox("paintbrush.fill", bg: accent.opacity(0.2), fg: accent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Customization")
                                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                                    Text("Theme, cover, slider & font")
                                        .font(.system(size: 12)).foregroundStyle(.white.opacity(0.4))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.22))
                            }
                            .padding(.horizontal, 16).padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)
                    }

                    settingsGroup("DEVELOPER") {
                        ShareLink(item: debugLogText) {
                            HStack(spacing: 14) {
                                iconBox("ladybug.fill", bg: Color.gray.opacity(0.2), fg: .gray)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Debug Log")
                                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                                    Text("Share for issue diagnosis")
                                        .font(.system(size: 12)).foregroundStyle(.white.opacity(0.4))
                                }
                                Spacer()
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 14)).foregroundStyle(.white.opacity(0.3))
                            }
                            .padding(.horizontal, 16).padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)
                    }

                    if firebaseManager.currentUser != nil {
                        Button { showLogoutConfirm = true } label: {
                            HStack(spacing: 14) {
                                iconBox("rectangle.portrait.and.arrow.right", bg: Color.red.opacity(0.15), fg: .red)
                                Text("Sign Out")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.red)
                                Spacer()
                            }
                            .padding(.horizontal, 16).padding(.vertical, 14)
                            .background(Color.red.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
                        }
                        .buttonStyle(ScaleButtonStyle(scale: 0.97))
                    }

                    Button { showClearDownloads = true } label: {
                        HStack(spacing: 14) {
                            iconBox("trash.fill", bg: Color.green.opacity(0.15), fg: .green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Remove Downloaded Songs")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.green)
                                Text("\(dm.offlineIDs.count) track\(dm.offlineIDs.count == 1 ? "" : "s") stored locally")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.green.opacity(0.55))
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .background(Color.green.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(ScaleButtonStyle(scale: 0.97))
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 120)
            }
            .background(bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("SETTINGS")
                        .font(.system(size: 12, weight: .black))
                        .kerning(2.5)
                        .foregroundStyle(.white)
                }
            }
        }
        .sheet(isPresented: $showCachingSheet) {
            CachingSheet(mode: $cachingMode, cacheListened: $cacheListened, cachePlaylists: $cachePlaylists)
                .environmentObject(themeManager)
                .presentationDetents([.medium])
                .presentationBackground(card)
                .presentationCornerRadius(28)
        }
        .confirmationDialog("Sign Out", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) { firebaseManager.logOut() }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Remove Downloaded Songs", isPresented: $showClearDownloads, titleVisibility: .visible) {
            Button("Remove All Downloads", role: .destructive) {
                for id in dm.offlineIDs {
                    dm.deleteDownload(trackID: id)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete all \(dm.offlineIDs.count) locally stored tracks. They can be re-downloaded from the Library.")
        }
        .alert("Display Name", isPresented: $showNameEdit) {
            TextField("Name", text: $editingName).autocorrectionDisabled()
            Button("Save") {
                let t = editingName.trimmingCharacters(in: .whitespaces)
                guard !t.isEmpty else { return }
                Task { try? await firebaseManager.updateDisplayName(t) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .onChange(of: avatarItem) { _, newItem in
            guard let item = newItem else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    try? await firebaseManager.updateAvatar(image)
                }
                avatarItem = nil
            }
        }
    }

    // MARK: - Profile card

    private func profileCard(_ user: AppUser) -> some View {
        HStack(spacing: 16) {
            PhotosPicker(selection: $avatarItem, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    if let img = user.avatarImage {
                        Image(uiImage: img)
                            .resizable().scaledToFill()
                            .frame(width: 66, height: 66)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(accent.opacity(0.15))
                            .frame(width: 66, height: 66)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 27))
                                    .foregroundStyle(accent)
                            )
                    }
                    Circle()
                        .fill(card)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white.opacity(0.6))
                        )
                        .offset(x: 3, y: 3)
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Button {
                    editingName = user.displayName
                    showNameEdit = true
                } label: {
                    HStack(spacing: 6) {
                        Text(user.displayName.isEmpty ? "Add your name" : user.displayName)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                        Image(systemName: "pencil")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
                .buttonStyle(.plain)

                Text("@\(user.username)")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.4))

                if !user.email.isEmpty {
                    Text(user.email)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.25))
                }
            }
            Spacer()
        }
        .padding(20)
        .background(card, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Helpers

    private func settingsGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .black)).kerning(2)
                .foregroundStyle(.white.opacity(0.3))
                .padding(.horizontal, 4)
            VStack(spacing: 0) { content() }
                .background(card, in: RoundedRectangle(cornerRadius: 18))
        }
    }

    private func settingsRow(icon: String, iconBg: Color, iconFg: Color, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                iconBox(icon, bg: iconBg, fg: iconFg)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                    Text(subtitle).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.4))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.22))
            }
            .padding(.horizontal, 16).padding(.vertical, 14).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggleRow(icon: String, iconBg: Color, iconFg: Color, title: String, value: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            iconBox(icon, bg: iconBg, fg: iconFg)
            Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
            Spacer()
            Toggle("", isOn: value)
                .toggleStyle(SwitchToggleStyle(tint: accent))
                .labelsHidden()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private func iconBox(_ icon: String, bg: Color, fg: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(bg).frame(width: 36, height: 36)
            Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(fg)
        }
    }

    private func rowDivider() -> some View {
        Divider().background(Color.white.opacity(0.06)).padding(.leading, 66)
    }

    private var debugLogText: String {
        """
        POSTOR Debug Log — \(Date())
        Audio Quality : Lossless FLAC (locked)
        Caching Mode  : \(cachingMode.label)
        Theme         : \(themeManager.current.name)
        Slider        : \(themeManager.sliderType.label)
        """
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
                            Circle().fill(on ? Color.white.opacity(0.18) : Color.white.opacity(0.07)).frame(width: 48, height: 48)
                            Image(systemName: m.icon).font(.system(size: 20)).foregroundStyle(.white)
                        }
                        Text(m.label).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                        Spacer()
                        if on { Image(systemName: "checkmark").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white) }
                    }
                    .padding(.horizontal, 20).padding(.vertical, 14)
                    .background(on ? Color.white.opacity(0.06) : Color.clear, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 12).padding(.vertical, 3)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(on ? Color.white.opacity(0.25) : .clear, lineWidth: 1).padding(.horizontal, 12).padding(.vertical, 3))
                }
                .buttonStyle(.plain)
            }
            Divider().background(Color.white.opacity(0.07)).padding(.horizontal, 20).padding(.vertical, 8)
            HStack {
                Text("Cache listened tracks").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                Spacer()
                Toggle("", isOn: $cacheListened).toggleStyle(SwitchToggleStyle(tint: themeManager.current.primary)).labelsHidden()
            }.padding(.horizontal, 20).padding(.vertical, 10)
            HStack {
                Text("Cache playlist tracks").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                Spacer()
                Toggle("", isOn: $cachePlaylists).toggleStyle(SwitchToggleStyle(tint: themeManager.current.primary)).labelsHidden()
            }.padding(.horizontal, 20).padding(.vertical, 10)
            Spacer()
        }
        .preferredColorScheme(.dark)
    }
}
