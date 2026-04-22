import AVFoundation
import Foundation
import UIKit

@MainActor
final class AudioPlayerService {

    var onTrackEnd:        (() -> Void)?
    var onTimeUpdate:      ((Double) -> Void)?
    var onDurationReady:   ((Double) -> Void)?
    var onPlayStateChange: ((Bool) -> Void)?
    var onLoadingChange:   ((Bool) -> Void)?

    private var player:         AVPlayer?
    private var currentItem:    AVPlayerItem?
    private var timeObserver:   Any?
    private var endObserver:    NSObjectProtocol?
    private var statusObserver: NSKeyValueObservation?
    private var bufferObserver: NSKeyValueObservation?
    private var rateObserver:   NSKeyValueObservation?

    private(set) var currentSpeed: Float = 1.0
    private(set) var isPitchPreserved: Bool = true
    // EQ is stored but not applied — AVPlayer uses the system audio pipeline.
    // A future MTAudioProcessingTap implementation can wire these back in.
    private(set) var eqGains: [Float] = [0, 0, 0, 0, 0]

    init() {
        DispatchQueue.global(qos: .userInitiated).async {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try? AVAudioSession.sharedInstance().setActive(true)
        }
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil, queue: .main
        ) { _ in
            try? AVAudioSession.sharedInstance().setActive(true)
        }
    }

    // MARK: - Playback

    func play(url: URL) {
        stop()
        onLoadingChange?(true)

        let item = AVPlayerItem(url: url)
        item.audioTimePitchAlgorithm = isPitchPreserved ? .spectral : .varispeed
        currentItem = item

        if player == nil {
            player = AVPlayer(playerItem: item)
        } else {
            player?.replaceCurrentItem(with: item)
        }

        // Periodic time updates (1 s resolution)
        let interval = CMTime(seconds: 1, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard time.isValid, !time.isIndefinite else { return }
            Task { @MainActor [weak self] in self?.onTimeUpdate?(time.seconds) }
        }

        // Duration becomes available once the item is ready
        statusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch item.status {
                case .readyToPlay:
                    let d = item.duration.seconds
                    if d.isFinite && d > 0 { self.onDurationReady?(d) }
                    self.onLoadingChange?(false)
                case .failed:
                    self.onLoadingChange?(false)
                default: break
                }
            }
        }

        // Signal loading done once enough data is buffered
        bufferObserver = item.observe(\.isPlaybackLikelyToKeepUp, options: [.new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                if item.isPlaybackLikelyToKeepUp { self?.onLoadingChange?(false) }
            }
        }

        // Play state mirrors AVPlayer.rate
        rateObserver = player?.observe(\.rate, options: [.new]) { [weak self] player, _ in
            Task { @MainActor [weak self] in self?.onPlayStateChange?(player.rate > 0) }
        }

        // End-of-track
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: item, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.onPlayStateChange?(false)
                self?.onTrackEnd?()
            }
        }

        // Start playback at the requested speed
        player?.rate = currentSpeed
        onPlayStateChange?(true)
    }

    // MARK: - Controls

    func pause() {
        player?.pause()
        onPlayStateChange?(false)
    }

    func resume() {
        player?.rate = currentSpeed
        onPlayStateChange?(true)
    }

    func stop() {
        if let obs = timeObserver { player?.removeTimeObserver(obs); timeObserver = nil }
        if let obs = endObserver  { NotificationCenter.default.removeObserver(obs); endObserver = nil }
        statusObserver?.invalidate(); statusObserver = nil
        bufferObserver?.invalidate(); bufferObserver = nil
        rateObserver?.invalidate();   rateObserver   = nil
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        currentItem = nil
        onPlayStateChange?(false)
        onTimeUpdate?(0)
        onDurationReady?(0)
    }

    func seek(to seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func setSpeed(_ rate: Float) {
        currentSpeed = rate
        if let p = player, p.rate != 0 { p.rate = rate }
    }

    func setPitchPreserved(_ on: Bool) {
        isPitchPreserved = on
        currentItem?.audioTimePitchAlgorithm = on ? .spectral : .varispeed
    }

    // MARK: - EQ (stored for future tap implementation)

    func setEQGain(_ gain: Float, band: Int) {
        guard band < eqGains.count else { return }
        eqGains[band] = gain
    }

    /// Quality is handled by transcoding selection, not post-processing EQ.
    func applyQualityEQ(_ gains: [Float]) {}
}
