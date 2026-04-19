import AVFoundation
import Foundation

@MainActor
final class AudioPlayerService {

    // MARK: - Callbacks
    var onTrackEnd:        (() -> Void)?
    var onTimeUpdate:      ((Double) -> Void)?
    var onDurationReady:   ((Double) -> Void)?
    var onPlayStateChange: ((Bool) -> Void)?
    var onLoadingChange:   ((Bool) -> Void)?

    // MARK: - Private state
    private var player:        AVPlayer?
    private var timeObserver:  Any?
    private var statusObserver: NSKeyValueObservation?
    private var lastReportedDuration: Double = 0
    private(set) var currentSpeed: Float = 1.0

    init() {
        Task.detached(priority: .userInitiated) {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try? AVAudioSession.sharedInstance().setActive(true)
        }
    }

    // MARK: - Playback

    func play(url: URL) {
        stop()
        lastReportedDuration = 0
        onLoadingChange?(true)

        let item   = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.automaticallyWaitsToMinimizeStalling = true
        self.player = player

        // Start playback immediately — AVPlayer buffers automatically
        player.play()
        player.rate = currentSpeed

        // KVO on status — report duration once known
        statusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch item.status {
                case .readyToPlay:
                    self.onLoadingChange?(false)
                    self.onPlayStateChange?(true)
                    let dur = item.duration.seconds
                    if dur.isFinite && dur > 0 {
                        self.lastReportedDuration = dur
                        self.onDurationReady?(dur)
                    }
                case .failed:
                    self.onLoadingChange?(false)
                    self.onPlayStateChange?(false)
                default: break
                }
            }
        }

        // Track end
        NotificationCenter.default.addObserver(
            self, selector: #selector(itemDidFinish),
            name: .AVPlayerItemDidPlayToEndTime, object: item
        )

        // Periodic time + duration fallback
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.onTimeUpdate?(time.seconds)
                // Pick up duration if it became available after readyToPlay
                let dur = self.player?.currentItem?.duration.seconds ?? 0
                if dur.isFinite && dur > 0 && dur != self.lastReportedDuration {
                    self.lastReportedDuration = dur
                    self.onDurationReady?(dur)
                }
            }
        }
    }

    func pause() {
        player?.pause()
        onPlayStateChange?(false)
    }

    func resume() {
        player?.play()
        player?.rate = currentSpeed
        onPlayStateChange?(true)
    }

    func stop() {
        statusObserver?.invalidate()
        statusObserver = nil
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        if let obs = timeObserver { player?.removeTimeObserver(obs); timeObserver = nil }
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

    @objc private func itemDidFinish() {
        onPlayStateChange?(false)
        onTrackEnd?()
    }
}
