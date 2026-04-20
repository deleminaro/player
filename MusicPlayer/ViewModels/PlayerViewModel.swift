import Foundation
import Combine
import WidgetKit
import ActivityKit

@MainActor
final class PlayerViewModel: ObservableObject {

    // MARK: - Published state

    @Published var currentTrack:      Track?       = nil
    @Published var playerState:       PlayerState  = .idle
    @Published var isPlaying:         Bool         = false
    @Published var currentTime:       Double       = 0
    @Published var duration:          Double       = 0
    @Published var playbackSpeed:     Float        = 1.0
    @Published var queue:             [QueueItem]  = []
    @Published var recentlyPlayed:    [Track]      = []
    @Published var showingNowPlaying: Bool         = false

    // MARK: - Services

    let audio = AudioPlayerService()
    private let sc = SoundCloudService.shared

    // MARK: - Live Activity

    private var liveActivity: Activity<MusicActivityAttributes>?

    // MARK: - Persistence keys

    private let kRecent = "mp_recently_played"
    private let kQueue  = "mp_queue"
    private let wSuite  = "group.com.ivansolomakha.musicplayer"

    // MARK: - Init

    init() {
        bindAudioCallbacks()
        loadPersisted()
    }

    // MARK: - Audio callback bridge

    private func bindAudioCallbacks() {
        audio.onPlayStateChange = { [weak self] playing in
            guard let self else { return }
            self.isPlaying   = playing
            self.playerState = playing ? .playing : (self.currentTrack == nil ? .idle : .paused)
            self.updateLiveActivity()
        }
        audio.onTimeUpdate    = { [weak self] t  in self?.currentTime = t }
        audio.onDurationReady = { [weak self] d  in self?.duration    = d }
        audio.onLoadingChange = { [weak self] on in
            if on { self?.playerState = .loading }
        }
        audio.onTrackEnd = { [weak self] in self?.skipNext() }
    }

    // MARK: - Playback

    func play(_ track: Track) {
        currentTrack = track
        playerState  = .loading
        addToRecent(track)
        updateWidgetData(track: track)
        startLiveActivity(track: track)

        Task {
            do {
                guard let transcoding = track.media?.progressiveTranscoding else {
                    playerState = .idle; return
                }
                let url = try await sc.resolveStreamURL(transcodingURL: transcoding.url)
                audio.play(url: url)
            } catch {
                print("[PlayerVM] play error: \(error.localizedDescription)")
                playerState = .idle
            }
        }
    }

    func togglePlayPause() {
        isPlaying ? audio.pause() : audio.resume()
    }

    func seek(to seconds: Double) {
        audio.seek(to: seconds)
    }

    func setSpeed(_ rate: Float) {
        playbackSpeed = rate
        audio.setSpeed(rate)
    }

    func setEQGain(_ gain: Float, band: Int) {
        audio.setEQGain(gain, band: band)
    }

    // MARK: - Queue navigation

    func skipNext() {
        guard !queue.isEmpty else { playerState = .idle; endLiveActivity(); return }
        if let idx = currentIndex() {
            let next = idx + 1
            if next < queue.count {
                play(queue[next].track)
            } else {
                playerState = .idle
                endLiveActivity()
            }
        } else {
            play(queue[0].track)
        }
    }

    func skipPrevious() {
        if currentTime > 3 { audio.seek(to: 0); return }
        guard let idx = currentIndex(), idx > 0 else { audio.seek(to: 0); return }
        play(queue[idx - 1].track)
    }

    private func currentIndex() -> Int? {
        guard let id = currentTrack?.id else { return nil }
        return queue.firstIndex { $0.track.id == id }
    }

    // MARK: - Queue management

    func addToQueue(_ track: Track) {
        guard !queue.contains(where: { $0.track.id == track.id }) else { return }
        queue.append(QueueItem(track: track))
        saveQueue()
    }

    func removeFromQueue(at offsets: IndexSet) {
        queue.remove(atOffsets: offsets)
        saveQueue()
    }

    func moveInQueue(from source: IndexSet, to destination: Int) {
        queue.move(fromOffsets: source, toOffset: destination)
        saveQueue()
    }

    // MARK: - Recently played

    private func addToRecent(_ track: Track) {
        recentlyPlayed.removeAll { $0.id == track.id }
        recentlyPlayed.insert(track, at: 0)
        if recentlyPlayed.count > 50 { recentlyPlayed = Array(recentlyPlayed.prefix(50)) }
        saveRecent()
    }

    // MARK: - Widget data

    private func updateWidgetData(track: Track) {
        guard let defaults = UserDefaults(suiteName: wSuite) else { return }
        defaults.set(track.title,    forKey: "widget_title")
        defaults.set(track.username, forKey: "widget_artist")
        defaults.set(track.highResArtworkURL ?? track.artworkURL, forKey: "widget_artwork")
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Live Activity

    private func startLiveActivity(track: Track) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        endLiveActivity()
        let state = MusicActivityAttributes.ContentState(
            title:      track.title,
            artist:     track.username,
            artworkURL: track.highResArtworkURL ?? track.artworkURL ?? "",
            isPlaying:  true,
            progress:   0
        )
        liveActivity = try? Activity<MusicActivityAttributes>.request(
            attributes: MusicActivityAttributes(),
            content: ActivityContent(state: state, staleDate: nil),
            pushType: nil
        )
    }

    private func updateLiveActivity() {
        guard let activity = liveActivity else { return }
        let progress = duration > 0 ? min(1, max(0, currentTime / duration)) : 0
        let state = MusicActivityAttributes.ContentState(
            title:      currentTrack?.title    ?? "",
            artist:     currentTrack?.username ?? "",
            artworkURL: currentTrack?.highResArtworkURL ?? currentTrack?.artworkURL ?? "",
            isPlaying:  isPlaying,
            progress:   progress
        )
        Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    private func endLiveActivity() {
        guard let activity = liveActivity else { return }
        liveActivity = nil
        Task {
            let state = MusicActivityAttributes.ContentState(
                title: "", artist: "", artworkURL: "", isPlaying: false, progress: 0
            )
            await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .immediate)
        }
    }

    // MARK: - Persistence

    private func loadPersisted() {
        if let data   = UserDefaults.standard.data(forKey: kRecent),
           let tracks = try? JSONDecoder().decode([Track].self, from: data) {
            recentlyPlayed = tracks
        }
        if let data   = UserDefaults.standard.data(forKey: kQueue),
           let tracks = try? JSONDecoder().decode([Track].self, from: data) {
            queue = tracks.map { QueueItem(track: $0) }
        }
    }

    private func saveRecent() {
        if let data = try? JSONEncoder().encode(recentlyPlayed) {
            UserDefaults.standard.set(data, forKey: kRecent)
        }
    }

    private func saveQueue() {
        let tracks = queue.map { $0.track }
        if let data = try? JSONEncoder().encode(tracks) {
            UserDefaults.standard.set(data, forKey: kQueue)
        }
    }
}
