import SwiftUI

struct OfflineTracksView: View {
    @EnvironmentObject var playerVM:    PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var dm = DownloadManager.shared

    private var bg:     Color { themeManager.current.background }
    private var accent: Color { themeManager.current.primary }

    private var offlineTracks: [Track] {
        let ids = dm.offlineIDs.union(dm.cachedIDs)
        var seen  = Set<Int>()
        var result: [Track] = []
        for t in playerVM.likedTracks + playerVM.recentlyPlayed {
            guard ids.contains(t.id), seen.insert(t.id).inserted else { continue }
            result.append(t)
        }
        return result
    }

    var body: some View {
        List {
            if offlineTracks.isEmpty {
                emptyState
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(offlineTracks) { track in
                        offlineRow(track)
                            .onTapGesture {
                                playerVM.playFromList(offlineTracks, startingWith: track)
                                playerVM.showingNowPlaying = true
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(bg)
                            .listRowSeparatorTint(Color.white.opacity(0.06))
                    }
                } header: {
                    HStack {
                        Text("\(offlineTracks.count) TRACKS AVAILABLE OFFLINE")
                            .font(.system(size: 10, weight: .black)).kerning(1.5)
                            .foregroundStyle(.white.opacity(0.3))
                        Spacer()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 6)
                    .listRowInsets(EdgeInsets())
                    .textCase(nil)
                }
            }
        }
        .listStyle(.plain)
        .background(bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("OFFLINE")
                    .font(.system(size: 12, weight: .black)).kerning(2.5)
                    .foregroundStyle(.white)
            }
            if !offlineTracks.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let s = offlineTracks.shuffled()
                        playerVM.playFromList(s, startingWith: s[0])
                        playerVM.showingNowPlaying = true
                    } label: {
                        Image(systemName: "shuffle")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(accent)
                    }
                }
            }
        }
    }

    private func offlineRow(_ track: Track) -> some View {
        HStack(spacing: 12) {
            ArtworkThumbnail(url: track.thumbnailArtworkURL, trackID: track.id)
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(themeManager.font(14, .semibold))
                    .foregroundStyle(playerVM.currentTrack?.id == track.id ? accent : .white)
                    .lineLimit(1)
                Text(track.username)
                    .font(themeManager.font(12))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: dm.offlineIDs.contains(track.id) ? "internaldrive" : "cylinder.split.1x2")
                .font(.system(size: 13))
                .foregroundStyle(accent.opacity(0.6))
            Text(track.durationFormatted)
                .font(themeManager.font(12))
                .foregroundStyle(.white.opacity(0.3))
                .monospacedDigit()
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "internaldrive")
                .font(.system(size: 44))
                .foregroundStyle(accent.opacity(0.25))
                .padding(.top, 60)
            Text("No Offline Tracks")
                .font(themeManager.font(18, .bold))
                .foregroundStyle(.white.opacity(0.6))
            Text("Download tracks from the Library\nor long-press any song.")
                .font(themeManager.font(13))
                .foregroundStyle(.white.opacity(0.3))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32).padding(.vertical, 60)
    }
}
