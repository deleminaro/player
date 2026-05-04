import Foundation
import Combine
import MediaPlayer
import UIKit

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
    @Published var recentlyPlayed:    [Track]         = []
    @Published var likedTracks:       [Track]         = []
    @Published var playlists:         [LocalPlaylist] = []
    @Published var recentSearches:    [String]        = []
    @Published var showingNowPlaying: Bool            = false
    @Published var isShuffling:       Bool            = false
    @Published var isRepeating:       Bool            = false
    @Published var isPitchPreserved:  Bool            = true

    var nextTrack: Track? {
        guard let idx = queue.firstIndex(where: { $0.track.id == currentTrack?.id }),
              idx + 1 < queue.count else { return nil }
        return queue[idx + 1].track
    }

    // MARK: - Services

    let audio = AudioPlayerService()
    private let sc = SoundCloudService.shared

    // MARK: - Persistence keys

    private let kRecent     = "mp_recently_played"
    private let kQueue      = "mp_queue"
    private let kLiked      = "mp_liked_tracks"
    private let kSearches   = "mp_recent_searches"
    private let kPlaylists  = "mp_playlists"
    private let kQuality    = "mp_audio_quality"
    private let kSpeed      = "mp_playback_speed"
    private let kEQGains    = "mp_eq_gains"
    private let kPitch      = "mp_pitch_preserved"

    // MARK: - Init

    init() {
        bindAudioCallbacks()
        bindSpotifyCallbacks()
        loadPersisted()
        setupRemoteCommands()
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.saveRecent(); self?.saveQueue()
                self?.saveLiked(); self?.saveSearches(); self?.savePlaylists()
            }
        }
    }

    private var currentQuality: AudioQuality {
        AudioQuality(rawValue: UserDefaults.standard.string(forKey: kQuality) ?? "") ?? .lossless
    }

    // MARK: - Audio callback bridge

    private func bindAudioCallbacks() {
        audio.onPlayStateChange = { [weak self] playing in
            guard let self else { return }
            self.isPlaying   = playing
            self.playerState = playing ? .playing : (self.currentTrack == nil ? .idle : .paused)
            if playing, let track = self.currentTrack {
                self.updateNowPlayingInfo(track: track)
            }
            self.updateNowPlayingPlaybackState()
        }
        audio.onTimeUpdate    = { [weak self] t in self?.currentTime = t }
        audio.onDurationReady = { [weak self] d in
            self?.duration = d
            self?.updateNowPlayingDuration(d)
        }
        audio.onLoadingChange = { [weak self] on in
            if on { self?.playerState = .loading }
        }
        audio.onTrackEnd = { [weak self] in self?.skipNext() }
    }

    private func bindSpotifyCallbacks() {
        let remote = SpotifyRemoteService.shared
        remote.onPlayStateChange = { [weak self] playing in
            guard let self, self.currentTrack?.source == .spotify else { return }
            self.isPlaying   = playing
            self.playerState = playing ? .playing : (self.currentTrack == nil ? .idle : .paused)
            if playing, let track = self.currentTrack { self.updateNowPlayingInfo(track: track) }
            self.updateNowPlayingPlaybackState()
        }
        remote.onConnectionFailed = { [weak self] in
            guard let self, self.currentTrack?.source == .spotify else { return }
            let track = self.currentTrack
            Task { @MainActor [weak self] in
                guard let self, self.currentTrack?.id == track?.id else { return }
                if let preview = track?.previewURL, let url = URL(string: preview) {
                    self.audio.play(url: url)
                } else {
                    self.playerState = .idle
                }
            }
        }
        remote.onTimeUpdate = { [weak self] t in
            guard let self, self.currentTrack?.source == .spotify else { return }
            self.currentTime = t
        }
        remote.onDurationReady = { [weak self] d in
            guard let self, self.currentTrack?.source == .spotify else { return }
            self.duration = d
            self.updateNowPlayingDuration(d)
        }
        remote.onTrackEnd = { [weak self] in
            guard let self, self.currentTrack?.source == .spotify else { return }
            self.skipNext()
        }
    }

    // MARK: - Playback

    func play(_ track: Track) {
        currentTrack = track
        playerState  = .loading
        addToRecent(track)
        updateNowPlayingInfo(track: track)
        MPRemoteCommandCenter.shared().likeCommand.isActive = isLiked(track)

        Task {
            do {
                // Local offline/cached file takes priority for both sources
                if let localURL = DownloadManager.shared.localURL(for: track.id) {
                    guard currentTrack?.id == track.id else { return }
                    audio.play(url: localURL)
                    return
                }
                // Spotify source — try App Remote first (opens Spotify for full track),
                // fall back to preview URL or SoundCloud search if unavailable
                if track.source == .spotify {
                    if let uri = track.spotifyURI,
                       let token = SpotifyService.shared.currentAccessToken {
                        SpotifyRemoteService.shared.play(uri: uri, accessToken: token)
                        return
                    }
                    if let preview = track.previewURL, let url = URL(string: preview) {
                        guard currentTrack?.id == track.id else { return }
                        audio.play(url: url)
                        return
                    }
                    // No preview and no URI — search SoundCloud for full track
                    let scResults = try? await sc.search(query: "\(track.title) \(track.username)")
                    guard currentTrack?.id == track.id else { return }
                    if let scTrack = scResults?.first,
                       let transcoding = scTrack.media?.transcoding(for: currentQuality) {
                        let url = try await sc.resolveStreamURL(transcodingURL: transcoding.url)
                        guard currentTrack?.id == track.id else { return }
                        audio.play(url: url)
                        return
                    }
                    if currentTrack?.id == track.id { audio.stop(); playerState = .idle }
                    return
                }
                // SoundCloud: resolve transcoding URL
                guard let transcoding = track.media?.transcoding(for: currentQuality) else {
                    if currentTrack?.id == track.id { audio.stop(); playerState = .idle }
                    return
                }
                let url = try await sc.resolveStreamURL(transcodingURL: transcoding.url)
                guard currentTrack?.id == track.id else { return }
                audio.play(url: url)
            } catch {
                if currentTrack?.id == track.id { playerState = .idle }
                print("[PlayerVM] play error: \(error.localizedDescription)")
            }
        }
    }

    func togglePlayPause() {
        if currentTrack?.source == .spotify, SpotifyRemoteService.shared.isConnected {
            isPlaying ? SpotifyRemoteService.shared.pause() : SpotifyRemoteService.shared.resume()
        } else {
            isPlaying ? audio.pause() : audio.resume()
        }
    }

    func seek(to seconds: Double) {
        if currentTrack?.source == .spotify, SpotifyRemoteService.shared.isConnected {
            SpotifyRemoteService.shared.seek(to: seconds)
        } else {
            audio.seek(to: seconds)
        }
        updateNowPlayingElapsed(seconds)
    }

    func setSpeed(_ rate: Float) {
        playbackSpeed = rate
        audio.setSpeed(rate)
        updateNowPlayingPlaybackState()
        UserDefaults.standard.set(Double(rate), forKey: kSpeed)
    }

    func togglePitchPreservation() {
        isPitchPreserved.toggle()
        audio.setPitchPreserved(isPitchPreserved)
        UserDefaults.standard.set(isPitchPreserved, forKey: kPitch)
    }

    func setEQGain(_ gain: Float, band: Int) {
        audio.setEQGain(gain, band: band)
        UserDefaults.standard.set(audio.eqGains.map { Double($0) }, forKey: kEQGains)
    }

    // MARK: - Queue navigation

    func skipNext() {
        if isRepeating, let t = currentTrack { play(t); return }
        guard !queue.isEmpty else { playerState = .idle; clearNowPlaying(); return }
        if let idx = currentIndex() {
            if isShuffling {
                let others = queue.indices.filter { $0 != idx }
                if let r = others.randomElement() { play(queue[r].track) } else { playerState = .idle; clearNowPlaying() }
            } else {
                let next = idx + 1
                if next < queue.count { play(queue[next].track) } else { playerState = .idle; clearNowPlaying() }
            }
        } else {
            play(queue[0].track)
        }
    }

    func skipPrevious() {
        if currentTime > 3 { seek(to: 0); return }
        guard let idx = currentIndex(), idx > 0 else { seek(to: 0); return }
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

    func playFromList(_ tracks: [Track], startingWith track: Track) {
        queue = tracks.map { QueueItem(track: $0) }
        saveQueue()
        play(track)
    }

    func removeFromQueue(at offsets: IndexSet) {
        queue.remove(atOffsets: offsets)
        saveQueue()
    }

    func moveInQueue(from source: IndexSet, to destination: Int) {
        queue.move(fromOffsets: source, toOffset: destination)
        saveQueue()
    }

    // MARK: - Playlists

    @discardableResult
    func createPlaylist(name: String) -> LocalPlaylist {
        let pl = LocalPlaylist(name: name)
        playlists.append(pl)
        savePlaylists()
        return pl
    }

    func addTrackToPlaylist(_ track: Track, playlistID: UUID) {
        guard let idx = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        guard !playlists[idx].tracks.contains(where: { $0.id == track.id }) else { return }
        playlists[idx].tracks.append(track)
        savePlaylists()
    }

    func removeTrackFromPlaylist(_ trackID: Int, playlistID: UUID) {
        guard let idx = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        playlists[idx].tracks.removeAll { $0.id == trackID }
        savePlaylists()
    }

    func deletePlaylist(_ id: UUID) {
        playlists.removeAll { $0.id == id }
        savePlaylists()
    }

    func renamePlaylist(_ id: UUID, to name: String) {
        guard let idx = playlists.firstIndex(where: { $0.id == id }) else { return }
        playlists[idx].name = name
        savePlaylists()
    }

    // MARK: - Liked tracks

    func isLiked(_ track: Track) -> Bool {
        likedTracks.contains { $0.id == track.id }
    }

    func toggleLike(_ track: Track) {
        if isLiked(track) {
            likedTracks.removeAll { $0.id == track.id }
        } else {
            likedTracks.insert(track, at: 0)
        }
        saveLiked()
        updateNowPlayingLikedState(track)
        Task { await FirebaseManager.shared.syncLikedTracks(likedTracks) }
    }

    func loadFromFirebase() async {
        let data = await FirebaseManager.shared.loadUserData()
        if !data.liked.isEmpty     { likedTracks = data.liked;     saveLiked() }
        if !data.playlists.isEmpty { playlists   = data.playlists; savePlaylists() }
    }

    private func updateNowPlayingLikedState(_ track: Track) {
        MPRemoteCommandCenter.shared().likeCommand.isActive = isLiked(track)
    }

    // MARK: - Recent searches

    func addRecentSearch(_ query: String) {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        recentSearches.removeAll { $0.lowercased() == q.lowercased() }
        recentSearches.insert(q, at: 0)
        if recentSearches.count > 10 { recentSearches = Array(recentSearches.prefix(10)) }
        saveSearches()
    }

    func clearRecentSearches() {
        recentSearches = []
        saveSearches()
    }

    // MARK: - Recently played

    private func addToRecent(_ track: Track) {
        recentlyPlayed.removeAll { $0.id == track.id }
        recentlyPlayed.insert(track, at: 0)
        if recentlyPlayed.count > 50 { recentlyPlayed = Array(recentlyPlayed.prefix(50)) }
        saveRecent()
    }

    // MARK: - Per-track custom artwork

    private func customArtworkURL(for trackID: Int) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("custom_artwork_\(trackID).jpg")
    }

    func customArtwork(for trackID: Int) -> UIImage? {
        guard let data = try? Data(contentsOf: customArtworkURL(for: trackID)) else { return nil }
        return UIImage(data: data)
    }

    func setCustomArtwork(_ image: UIImage, for trackID: Int) {
        if let data = image.jpegData(compressionQuality: 0.85) {
            try? data.write(to: customArtworkURL(for: trackID))
        }
        objectWillChange.send()
        guard currentTrack?.id == trackID else { return }
        let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPMediaItemPropertyArtwork] = artwork
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func removeCustomArtwork(for trackID: Int) {
        try? FileManager.default.removeItem(at: customArtworkURL(for: trackID))
        objectWillChange.send()
        if currentTrack?.id == trackID, let track = currentTrack {
            updateNowPlayingInfo(track: track)
        }
    }

    // MARK: - MPNowPlayingInfoCenter

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            self?.audio.resume(); return .success
        }
        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            self?.audio.pause(); return .success
        }
        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause(); return .success
        }
        center.nextTrackCommand.isEnabled = true
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.skipNext(); return .success
        }
        center.previousTrackCommand.isEnabled = true
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.skipPrevious(); return .success
        }
        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.seek(to: e.positionTime)
            return .success
        }

        center.likeCommand.isEnabled = true
        center.likeCommand.localizedTitle = "Favorite"
        center.likeCommand.addTarget { [weak self] _ in
            guard let self, let track = self.currentTrack else { return .commandFailed }
            Task { @MainActor in self.toggleLike(track) }
            return .success
        }
    }

    private func updateNowPlayingInfo(track: Track) {
        let info: [String: Any] = [
            MPMediaItemPropertyTitle:               track.title,
            MPMediaItemPropertyArtist:              track.username,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: 0.0,
            MPMediaItemPropertyPlaybackDuration:    duration > 0 ? duration : Double(track.duration) / 1000,
            MPNowPlayingInfoPropertyPlaybackRate:   1.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        // Fetch artwork in background — custom per-track artwork takes priority
        let trackID = track.id
        let artworkURLStr = track.highResArtworkURL ?? track.artworkURL
        Task.detached { [trackID, artworkURLStr] in
            var image: UIImage?
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let customPath = docs.appendingPathComponent("custom_artwork_\(trackID).jpg")
            if let data = try? Data(contentsOf: customPath) {
                image = UIImage(data: data)
            } else if let urlStr = artworkURLStr,
                      let url = URL(string: urlStr),
                      let (data, _) = try? await URLSession.shared.data(from: url) {
                image = UIImage(data: data)
            }
            guard let img = image else { return }
            let artwork = MPMediaItemArtwork(boundsSize: img.size) { _ in img }
            await MainActor.run {
                var updated = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? info
                updated[MPMediaItemPropertyArtwork] = artwork
                MPNowPlayingInfoCenter.default().nowPlayingInfo = updated
            }
        }
    }

    private func updateNowPlayingPlaybackState() {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate]        = isPlaying ? Double(playbackSpeed) : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func updateNowPlayingDuration(_ d: Double) {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPMediaItemPropertyPlaybackDuration] = d
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func updateNowPlayingElapsed(_ t: Double) {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = t
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func clearNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - Persistence

    private func loadPersisted() {
        let d = UserDefaults.standard
        if let data = d.data(forKey: kRecent),
           let tracks = try? JSONDecoder().decode([Track].self, from: data) {
            recentlyPlayed = tracks
        }
        if let data = d.data(forKey: kQueue),
           let tracks = try? JSONDecoder().decode([Track].self, from: data) {
            queue = tracks.map { QueueItem(track: $0) }
        }
        if let data = d.data(forKey: kLiked),
           let tracks = try? JSONDecoder().decode([Track].self, from: data) {
            likedTracks = tracks
        }
        recentSearches = d.stringArray(forKey: kSearches) ?? []
        if let data = d.data(forKey: kPlaylists),
           let pls = try? JSONDecoder().decode([LocalPlaylist].self, from: data) {
            playlists = pls
        }

        // Restore playback speed
        let savedSpeed = Float(d.double(forKey: kSpeed))
        if savedSpeed > 0 {
            playbackSpeed = savedSpeed
            audio.setSpeed(savedSpeed)
        }

        // Restore EQ gains (stored as [Double] for plist compatibility)
        if let gains = d.array(forKey: kEQGains) as? [Double] {
            for (i, g) in gains.enumerated() where i < 5 {
                audio.setEQGain(Float(g), band: i)
            }
        }

        // Restore pitch preservation toggle
        if d.object(forKey: kPitch) != nil {
            isPitchPreserved = d.bool(forKey: kPitch)
            audio.setPitchPreserved(isPitchPreserved)
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

    private func savePlaylists() {
        if let data = try? JSONEncoder().encode(playlists) {
            UserDefaults.standard.set(data, forKey: kPlaylists)
        }
        Task { await FirebaseManager.shared.syncPlaylists(playlists) }
    }

    private func saveLiked() {
        if let data = try? JSONEncoder().encode(likedTracks) {
            UserDefaults.standard.set(data, forKey: kLiked)
        }
    }

    private func saveSearches() {
        UserDefaults.standard.set(recentSearches, forKey: kSearches)
    }
}
