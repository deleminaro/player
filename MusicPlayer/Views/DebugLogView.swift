import SwiftUI

struct DebugLogView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var playerVM:     PlayerViewModel
    @EnvironmentObject var firebaseManager: FirebaseManager
    @ObservedObject private var logger  = AppLogger.shared
    @StateObject    private var dm      = DownloadManager.shared
    @StateObject    private var network = NetworkMonitor.shared

    @State private var showClearConfirm = false
    @State private var filterCategory: String? = nil
    @State private var searchText = ""

    private var bg:     Color { themeManager.current.background }
    private var card:   Color { themeManager.current.card }
    private var accent: Color { themeManager.current.primary }

    // MARK: - Snapshot

    private var snapshotText: String {
        let user = firebaseManager.currentUser
        let track = playerVM.currentTrack
        let offlineBytes = dm.offlineIDs.reduce(0) { acc, id in
            acc + (try? FileManager.default.attributesOfItem(
                atPath: dm.offlineDir.appendingPathComponent("\(id).mp3").path)[.size] as? Int64 ?? 0) ?? 0
        }
        return """
        Device     : \(UIDevice.current.name) / iOS \(UIDevice.current.systemVersion)
        App        : POSTOR
        Date       : \(Date())

        ── User ──────────────────────────
        Firebase   : \(user != nil ? "signed in as \(user!.username) (\(user!.uid))" : "not signed in")
        Spotify    : \(SpotifyService.shared.isAuthenticated ? "authenticated" : "not authenticated")

        ── Network ───────────────────────
        Connected  : \(network.isConnected ? "yes" : "NO — offline")

        ── Playback ──────────────────────
        State      : \(playerVM.playerState)
        Track      : \(track.map { "'\($0.title)' by \($0.username) [\($0.source.rawValue)]" } ?? "none")
        Speed      : \(playerVM.playbackSpeed)×
        Repeat     : \(playerVM.repeatMode.rawValue)
        Shuffle    : \(playerVM.isShuffling)
        Queue      : \(playerVM.queue.count) tracks
        Liked      : \(playerVM.likedTracks.count) tracks
        Playlists  : \(playerVM.playlists.count)

        ── Downloads ─────────────────────
        Offline    : \(dm.offlineIDs.count) tracks (~\(offlineBytes / 1_000_000) MB)
        Cached     : \(dm.cachedIDs.count) tracks
        In-progress: \(dm.downloading.count)

        ── Settings ──────────────────────
        Quality    : Lossless FLAC (locked)
        Theme      : \(themeManager.current.name)
        """
    }

    // MARK: - Filtered entries

    private var visibleEntries: [LogEntry] {
        logger.entries
            .filter { filterCategory == nil || $0.category == filterCategory }
            .filter { searchText.isEmpty || $0.message.localizedCaseInsensitiveContains(searchText) || $0.category.localizedCaseInsensitiveContains(searchText) }
            .reversed()
    }

    private var categories: [String] {
        Array(Set(logger.entries.map(\.category))).sorted()
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            categoryFilter
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        snapshotCard
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                    } header: {
                        sectionHeader("SYSTEM SNAPSHOT")
                    }

                    Section {
                        if visibleEntries.isEmpty {
                            Text("No log entries yet.")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.3))
                                .padding(20)
                        } else {
                            ForEach(visibleEntries) { entry in
                                logRow(entry)
                                    .padding(.horizontal, 16)
                                Divider()
                                    .background(Color.white.opacity(0.04))
                                    .padding(.leading, 16)
                            }
                        }
                        Spacer().frame(height: 100)
                    } header: {
                        sectionHeader("EVENTS (\(visibleEntries.count))")
                    }
                }
            }
        }
        .background(bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("DEBUG LOG")
                    .font(.system(size: 12, weight: .black)).kerning(2.5)
                    .foregroundStyle(.white)
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                ShareLink(item: logger.export(snapshot: snapshotText)) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accent)
                }
                Button { showClearConfirm = true } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.red.opacity(0.8))
                }
            }
        }
        .confirmationDialog("Clear Log", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Clear All Entries", role: .destructive) { logger.clear() }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Components

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.4))
            TextField("Filter entries…", text: $searchText)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(card, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "All", selected: filterCategory == nil) {
                    filterCategory = nil
                }
                ForEach(categories, id: \.self) { cat in
                    filterChip(label: cat, selected: filterCategory == cat, color: color(for: cat)) {
                        filterCategory = filterCategory == cat ? nil : cat
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
    }

    private func filterChip(label: String, selected: Bool, color: Color = .white, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(selected ? .black : color.opacity(0.7))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selected ? color : card, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var snapshotCard: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(snapshotText)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.65))
                .padding(14)
        }
        .background(card, in: RoundedRectangle(cornerRadius: 14))
    }

    private func logRow(_ entry: LogEntry) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(entry.timestamp)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))
                .frame(width: 80, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.category.uppercased())
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(color(for: entry.category))
                Text(entry.message)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 7)
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 9, weight: .black)).kerning(1.8)
                .foregroundStyle(.white.opacity(0.3))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(bg)
    }

    private func color(for category: String) -> Color {
        switch category {
        case "Player":   return .blue
        case "Download": return .green
        case "Network":  return .yellow
        case "Firebase": return .orange
        case "Spotify":  return Color(red: 0.11, green: 0.73, blue: 0.33)
        case "Wave":     return .purple
        default:         return .white
        }
    }
}
