import AVFoundation
import Foundation

// Runs entirely on MainActor so @Published-equivalent callbacks always fire on main thread.
@MainActor
final class AudioPlayerService {

    // MARK: - Callbacks (set by PlayerViewModel)
    var onTrackEnd:          (() -> Void)?
    var onTimeUpdate:        ((Double) -> Void)?
    var onDurationReady:     ((Double) -> Void)?
    var onPlayStateChange:   ((Bool) -> Void)?
    var onLoadingChange:     ((Bool) -> Void)?

    // MARK: - Private state
    private var player:       AVPlayer?
    private var timeObserver: Any?
    private(set) var currentSpeed: Float = 1.0

    // MARK: - Setup

    init() {
        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[AudioPlayer] Session setup error: \(error)")
        }
    }

    // MARK: - Playback control

    func play(url: URL) {
        stop()
        onLoadingChange?(true)

        let item   = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        self.player = player

        // Ready-to-play observer
        Task { @MainActor in
            for await _ in item.publisher(for: \.status).values {
                guard item.status == .readyToPlay else { continue }
                let dur = item.duration.seconds
                if dur.isFinite { self.onDurationReady?(dur) }
                self.onLoadingChange?(false)
                player.rate = self.currentSpeed          // honours pre-set speed
                self.onPlayStateChange?(true)
                break
            }
        }

        // Track-end observer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(itemDidFinish),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )

        // Periodic time observer (every 0.5 s)
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.onTimeUpdate?(time.seconds)
        }
    }

    func pause() {
        player?.pause()
        onPlayStateChange?(false)
    }

    func resume() {
        player?.rate = currentSpeed
        onPlayStateChange?(true)
    }

    func stop() {
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        if let obs = timeObserver {
            player?.removeTimeObserver(obs)
            timeObserver = nil
        }
        player?.pause()
        player = nil
        onPlayStateChange?(false)
        onTimeUpdate?(0)
        onDurationReady?(0)
    }

    func seek(to seconds: Double) {
        let t = CMTime(seconds: seconds, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player?.seek(to: t, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func setSpeed(_ rate: Float) {
        currentSpeed = rate
        guard let player, player.rate != 0 else { return }
        player.rate = rate
    }

    // MARK: - Notification

    @objc private func itemDidFinish() {
        onPlayStateChange?(false)
        onTrackEnd?()
    }
}
