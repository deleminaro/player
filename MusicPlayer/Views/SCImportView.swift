import SwiftUI

struct SCImportView: View {
    @EnvironmentObject var playerVM:     PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    @State private var profileInput = ""
    @State private var phase: Phase  = .idle
    @State private var destination: Destination = .likes
    @State private var selectedPlaylistID: UUID? = nil
    @State private var showNewPlaylist = false
    @State private var newPlaylistName = ""
    @FocusState private var focused: Bool

    private let scOrange = Color(red: 1.0, green: 0.34, blue: 0.0)

    private enum Destination { case likes, playlist }

    private enum Phase: Equatable {
        case idle
        case loading
        case ready([Track])
        case done(Int)
        case error(String)

        static func == (lhs: Phase, rhs: Phase) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.loading, .loading), (.done, .done): return true
            case (.ready(let a), .ready(let b)): return a.count == b.count
            case (.error(let a), .error(let b)): return a == b
            default: return false
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 36, height: 4)
                .padding(.top, 14)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(scOrange.opacity(0.14))
                                .frame(width: 64, height: 64)
                            Image(systemName: "square.and.arrow.down.fill")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(scOrange)
                        }
                        .padding(.top, 20)

                        Text("Import SoundCloud Likes")
                            .font(.app(20, .bold))
                            .foregroundStyle(.white)

                        Text("Paste your SoundCloud Likes link.\nOpen SoundCloud → Likes → Share → Copy Link.")
                            .font(.app(13))
                            .foregroundStyle(.white.opacity(0.45))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.bottom, 24)

                    // Input field
                    HStack(spacing: 12) {
                        Image(systemName: "link")
                            .font(.app(15))
                            .foregroundStyle(.white.opacity(0.35))
                            .frame(width: 20)

                        TextField("soundcloud.com/you/likes", text: $profileInput)
                            .foregroundStyle(.white)
                            .tint(.white)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .focused($focused)
                            .submitLabel(.search)
                            .onSubmit { fetchTracks() }

                        if !profileInput.isEmpty {
                            Button { profileInput = ""; phase = .idle } label: {
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

                    // Status / destination section
                    Group {
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
                            .padding(.top, 20)

                        case .ready(let tracks):
                            readySection(tracks)

                        case .done(let count):
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                Text(count == 0
                                     ? "No new tracks found."
                                     : "\(count) track\(count == 1 ? "" : "s") added.")
                                    .font(.app(14, .semibold)).foregroundStyle(.white)
                            }
                            .padding(.top, 20)
                            .transition(.scale(scale: 0.85).combined(with: .opacity))

                        case .error(let msg):
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                                Text(msg)
                                    .font(.app(13))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .lineLimit(2)
                            }
                            .padding(.top, 20)
                            .transition(.opacity)
                        }
                    }
                    .animation(.spring(duration: 0.28), value: phase)
                    .padding(.bottom, 20)
                }
                .padding(.bottom, 8)
            }

            Spacer(minLength: 0)

            // Bottom buttons
            VStack(spacing: 10) {
                Button(action: primaryAction) {
                    Text(primaryLabel)
                        .font(.app(16, .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(primaryEnabled ? .white : Color.white.opacity(0.3),
                                    in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(ScaleButtonStyle(scale: 0.96))
                .disabled(!primaryEnabled)
                .padding(.horizontal, 24)

                Button("Skip for now") { dismiss() }
                    .font(.app(13))
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.bottom, 48)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { focused = true }
        }
        .alert("New Playlist", isPresented: $showNewPlaylist) {
            TextField("Playlist name", text: $newPlaylistName).autocorrectionDisabled()
            Button("Create") {
                let name = newPlaylistName.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return }
                let pl = playerVM.createPlaylist(name: name)
                selectedPlaylistID = pl.id
                newPlaylistName = ""
            }
            Button("Cancel", role: .cancel) { newPlaylistName = "" }
        }
    }

    // MARK: - Ready section (destination picker)

    @ViewBuilder
    private func readySection(_ tracks: [Track]) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "music.note.list")
                    .foregroundStyle(scOrange)
                Text("\(tracks.count) tracks found")
                    .font(.app(14, .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.top, 20)

            // Destination picker
            VStack(alignment: .leading, spacing: 10) {
                Text("ADD TO")
                    .font(.app(10, .black)).kerning(2)
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.horizontal, 4)

                // Likes option
                destinationRow(
                    icon: "heart.fill",
                    iconColor: .pink,
                    title: "Library (Likes)",
                    subtitle: "Added to your liked tracks",
                    selected: destination == .likes
                ) { destination = .likes }

                // Playlist option
                destinationRow(
                    icon: "music.note.list",
                    iconColor: themeManager.current.primary,
                    title: "Playlist",
                    subtitle: destination == .playlist && selectedPlaylistID != nil
                        ? playerVM.playlists.first(where: { $0.id == selectedPlaylistID })?.name ?? "Select playlist"
                        : "Select a playlist",
                    selected: destination == .playlist
                ) { destination = .playlist }

                // Playlist selector (shown when .playlist is chosen)
                if destination == .playlist {
                    VStack(spacing: 0) {
                        ForEach(playerVM.playlists) { pl in
                            Button {
                                selectedPlaylistID = pl.id
                            } label: {
                                HStack(spacing: 12) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white.opacity(0.08))
                                        .frame(width: 36, height: 36)
                                        .overlay(
                                            Image(systemName: "music.note.list")
                                                .font(.app(13))
                                                .foregroundStyle(.white.opacity(0.5))
                                        )
                                    Text(pl.name)
                                        .font(.app(14, .semibold))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    if selectedPlaylistID == pl.id {
                                        Image(systemName: "checkmark")
                                            .font(.app(13, .semibold))
                                            .foregroundStyle(themeManager.current.primary)
                                    }
                                }
                                .padding(.horizontal, 14).padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            showNewPlaylist = true
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(themeManager.current.primary.opacity(0.15))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "plus")
                                        .font(.app(13, .bold))
                                        .foregroundStyle(themeManager.current.primary)
                                }
                                Text("New Playlist")
                                    .font(.app(14, .semibold))
                                    .foregroundStyle(themeManager.current.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                    }
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .animation(.spring(duration: 0.25), value: destination)
                }
            }
            .padding(.horizontal, 24)
        }
    }

    private func destinationRow(icon: String, iconColor: Color, title: String,
                                subtitle: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.app(15, .semibold))
                        .foregroundStyle(iconColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.app(14, .semibold)).foregroundStyle(.white)
                    Text(subtitle).font(.app(11)).foregroundStyle(.white.opacity(0.4))
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.app(18))
                    .foregroundStyle(selected ? themeManager.current.primary : .white.opacity(0.2))
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(selected ? Color.white.opacity(0.07) : Color.white.opacity(0.04),
                        in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(selected ? themeManager.current.primary.opacity(0.4) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.2), value: selected)
    }

    // MARK: - Button helpers

    private var primaryLabel: String {
        switch phase {
        case .loading:         return "Fetching…"
        case .ready:           return destination == .playlist && selectedPlaylistID == nil
                                      ? "Select a Playlist" : "Import"
        case .done:            return "Done"
        default:               return "Fetch Likes"
        }
    }

    private var primaryEnabled: Bool {
        switch phase {
        case .loading:         return false
        case .ready:           return destination == .likes || selectedPlaylistID != nil
        case .done:            return true
        default:               return !profileInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func primaryAction() {
        switch phase {
        case .done:
            dismiss()
        case .ready(let tracks):
            commitImport(tracks)
        default:
            fetchTracks()
        }
    }

    // MARK: - Logic

    private func fetchTracks() {
        let input = profileInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        focused = false
        phase = .loading

        Task {
            do {
                let sc   = SoundCloudService.shared
                let user = try await sc.resolveUser(permalink: input)
                let tracks = try await sc.fetchUserLikes(userID: user.id)
                await MainActor.run {
                    withAnimation { phase = .ready(tracks) }
                }
            } catch let err as SoundCloudService.SCError {
                let msg: String
                switch err {
                case .badResponse(404): msg = "Profile not found. Check your username."
                default: msg = err.errorDescription ?? "Something went wrong."
                }
                await MainActor.run { withAnimation { phase = .error(msg) } }
            } catch {
                await MainActor.run { withAnimation { phase = .error(error.localizedDescription) } }
            }
        }
    }

    private func commitImport(_ tracks: [Track]) {
        var added = 0
        if destination == .likes {
            added = playerVM.importSCLikes(tracks)
        } else if let pid = selectedPlaylistID {
            for track in tracks {
                playerVM.addTrackToPlaylist(track, playlistID: pid)
                added += 1
            }
            Task { await FirebaseManager.shared.syncLikedTracks(playerVM.likedTracks) }
        }
        withAnimation { phase = .done(added) }
    }
}
