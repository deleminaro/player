import SwiftUI

struct DebugLogView: View {
    @EnvironmentObject var themeManager:    ThemeManager
    @EnvironmentObject var playerVM:        PlayerViewModel
    @EnvironmentObject var firebaseManager: FirebaseManager
    @ObservedObject private var logger  = AppLogger.shared
    @StateObject    private var dm      = DownloadManager.shared
    @StateObject    private var network = NetworkMonitor.shared

    @State private var showClearConfirm = false
    @State private var filterCategory: String? = nil
    @State private var searchText = ""

    private var bg:   Color { themeManager.current.background }
    private var card: Color { themeManager.current.card }
    private var accent: Color { themeManager.current.primary }

    // MARK: - Snapshot rows (shown inline at top of the stream)

    private struct SnapLine: Identifiable {
        let id   = UUID()
        let label: String
        let value: String
    }

    private var snapLines: [SnapLine] {
        let user  = firebaseManager.currentUser
        let track = playerVM.currentTrack
        let offlineMB = dm.offlineIDs.reduce(0) { acc, id in
            let u = dm.offlineDir.appendingPathComponent("\(id).mp3")
            return acc + ((try? FileManager.default.attributesOfItem(atPath: u.path)[.size] as? Int64) ?? 0)
        } / 1_000_000
        return [
            .init(label: "device",    value: "\(UIDevice.current.name) · iOS \(UIDevice.current.systemVersion)"),
            .init(label: "network",   value: network.isConnected ? "connected" : "OFFLINE"),
            .init(label: "firebase",  value: user.map { "signed in · \($0.username) (\($0.uid))" } ?? "not signed in"),
            .init(label: "spotify",   value: SpotifyService.shared.isAuthenticated ? "authenticated" : "not authenticated"),
            .init(label: "playback",  value: "\(playerVM.playerState) · \(playerVM.playbackSpeed)× · repeat:\(playerVM.repeatMode.rawValue) · shuffle:\(playerVM.isShuffling)"),
            .init(label: "track",     value: track.map { "'\($0.title)' by \($0.username) [\($0.source.rawValue)]" } ?? "none"),
            .init(label: "queue",     value: "\(playerVM.queue.count) tracks"),
            .init(label: "liked",     value: "\(playerVM.likedTracks.count) tracks · \(playerVM.playlists.count) playlists"),
            .init(label: "offline",   value: "\(dm.offlineIDs.count) tracks (~\(offlineMB) MB) · cached:\(dm.cachedIDs.count) · active:\(dm.downloading.count)"),
            .init(label: "theme",     value: themeManager.current.name),
        ]
    }

    // MARK: - Export text

    private var exportText: String {
        let snap = snapLines.map { "[\(Date())] [System] \($0.label): \($0.value)" }.joined(separator: "\n")
        return logger.export(snapshot: snap)
    }

    // MARK: - Filtered events

    private var visibleEntries: [LogEntry] {
        logger.entries
            .filter { filterCategory == nil || $0.category == filterCategory }
            .filter { searchText.isEmpty
                || $0.message.localizedCaseInsensitiveContains(searchText)
                || $0.category.localizedCaseInsensitiveContains(searchText) }
            .reversed()
    }

    private var allCategories: [String] {
        Array(Set(logger.entries.map(\.category))).sorted()
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            searchAndFilter
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    // ── Snapshot lines ──
                    ForEach(snapLines) { line in
                        snapRow(line)
                        lineDivider
                    }
                    // separator between snapshot and events
                    HStack {
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 1)
                    }
                    .padding(.vertical, 6)
                    // ── Event rows ──
                    if visibleEntries.isEmpty {
                        Text(logger.entries.isEmpty ? "No events yet — start playing music." : "No matches.")
                            .font(.app(12))
                            .foregroundStyle(.white.opacity(0.3))
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                    } else {
                        ForEach(visibleEntries) { entry in
                            eventRow(entry)
                            lineDivider
                        }
                    }
                    Spacer().frame(height: 100)
                }
                .padding(.top, 8)
            }
        }
        .background(bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("DEBUG LOG")
                    .font(.app(12, .black)).kerning(2.5)
                    .foregroundStyle(.white)
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                ShareLink(item: exportText) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.app(14, .semibold))
                        .foregroundStyle(accent)
                }
                Button { showClearConfirm = true } label: {
                    Image(systemName: "trash")
                        .font(.app(14, .semibold))
                        .foregroundStyle(.red.opacity(0.8))
                }
            }
        }
        .confirmationDialog("Clear Log", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Clear All Entries", role: .destructive) { logger.clear() }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Top bar (search + filter)

    private var searchAndFilter: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.app(13))
                    .foregroundStyle(.white.opacity(0.35))
                TextField("Search…", text: $searchText)
                    .font(.app(13))
                    .foregroundStyle(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.app(13))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(card, in: RoundedRectangle(cornerRadius: 11))
            .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    chip("All", selected: filterCategory == nil, color: .white) { filterCategory = nil }
                    ForEach(allCategories, id: \.self) { cat in
                        chip(cat, selected: filterCategory == cat, color: color(for: cat)) {
                            filterCategory = filterCategory == cat ? nil : cat
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 8)
            }
            Divider().background(Color.white.opacity(0.06))
        }
    }

    // MARK: - Rows

    private func snapRow(_ line: SnapLine) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("SYS")
                .font(.app(9, .black))
                .foregroundStyle(.white.opacity(0.25))
                .frame(width: 38, alignment: .leading)
                .padding(.top, 1)
            Text(line.label)
                .font(.app(11))
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 68, alignment: .leading)
            Text(line.value)
                .font(.app(11))
                .foregroundStyle(snapValueColor(line.label, value: line.value))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16).padding(.vertical, 5)
    }

    private func eventRow(_ entry: LogEntry) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(entry.category.prefix(3).uppercased())
                .font(.app(9, .black))
                .foregroundStyle(color(for: entry.category))
                .frame(width: 38, alignment: .leading)
                .padding(.top, 1)
            Text(entry.timestamp)
                .font(.app(10))
                .foregroundStyle(.white.opacity(0.3))
                .frame(width: 68, alignment: .leading)
            Text(entry.message)
                .font(.app(12))
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16).padding(.vertical, 6)
    }

    private var lineDivider: some View {
        Divider()
            .background(Color.white.opacity(0.05))
            .padding(.leading, 16)
    }

    // MARK: - Chip

    private func chip(_ label: String, selected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.app(11, .semibold))
                .foregroundStyle(selected ? .black : color.opacity(0.7))
                .padding(.horizontal, 11).padding(.vertical, 5)
                .background(selected ? color : card, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Colors

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

    private func snapValueColor(_ label: String, value: String) -> Color {
        switch label {
        case "network":  return value.contains("OFFLINE") ? .red : .green
        case "firebase": return value.contains("not") ? .white.opacity(0.35) : .orange
        case "spotify":  return value.contains("not") ? .white.opacity(0.35) : Color(red: 0.11, green: 0.73, blue: 0.33)
        case "track":    return value == "none" ? .white.opacity(0.35) : .white
        default:         return .white.opacity(0.7)
        }
    }
}
