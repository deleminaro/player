import AVFoundation
import Foundation
import MediaToolbox
import UIKit

// MARK: - 5-band peaking EQ (Direct Form II Transposed biquad)

private final class EQState: @unchecked Sendable {
    private let frequencies: [Double] = [60, 230, 910, 3600, 14000]
    private let q: Double = 0.707

    private var gains      = [Float](repeating: 0, count: 5)
    private var sampleRate: Double = 44100

    private var b0 = [Float](repeating: 1, count: 5)
    private var b1 = [Float](repeating: 0, count: 5)
    private var b2 = [Float](repeating: 0, count: 5)
    private var a1 = [Float](repeating: 0, count: 5)
    private var a2 = [Float](repeating: 0, count: 5)

    // Delay state per [band][channel], up to 8 channels
    private var w1 = [[Float]](repeating: [Float](repeating: 0, count: 8), count: 5)
    private var w2 = [[Float]](repeating: [Float](repeating: 0, count: 8), count: 5)

    var currentGains: [Float] { gains }

    func setGain(_ gain: Float, band: Int) {
        gains[band] = gain
        recompute(band: band)
        w1[band] = [Float](repeating: 0, count: 8)
        w2[band] = [Float](repeating: 0, count: 8)
    }

    func prepare(sampleRate sr: Double) {
        sampleRate = sr
        for i in 0..<5 { recompute(band: i) }
        w1 = [[Float]](repeating: [Float](repeating: 0, count: 8), count: 5)
        w2 = [[Float]](repeating: [Float](repeating: 0, count: 8), count: 5)
    }

    func process(buffer: UnsafeMutablePointer<Float>, frameCount: Int, channel: Int) {
        let ch = min(channel, 7)
        for b in 0..<5 {
            guard abs(gains[b]) > 0.001 else { continue }
            let _b0 = b0[b], _b1 = b1[b], _b2 = b2[b]
            let _a1 = a1[b], _a2 = a2[b]
            var s1 = w1[b][ch], s2 = w2[b][ch]
            for n in 0..<frameCount {
                let x = buffer[n]
                let y = _b0 * x + s1
                s1 = _b1 * x - _a1 * y + s2
                s2 = _b2 * x - _a2 * y
                buffer[n] = y
            }
            w1[b][ch] = s1
            w2[b][ch] = s2
        }
    }

    // Audio EQ Cookbook — Peaking EQ coefficients
    private func recompute(band: Int) {
        let gain = gains[band]
        guard abs(gain) > 0.001 else {
            b0[band] = 1; b1[band] = 0; b2[band] = 0
            a1[band] = 0; a2[band] = 0
            return
        }
        let A     = pow(10.0, Double(gain) / 40.0)
        let w0    = 2.0 * .pi * frequencies[band] / sampleRate
        let cosW0 = cos(w0)
        let alpha = sin(w0) / (2.0 * q)
        let n_b0  =  1.0 + alpha * A
        let n_b12 = -2.0 * cosW0          // b1 == a1 for peaking EQ
        let n_b2  =  1.0 - alpha * A
        let a0    =  1.0 + alpha / A
        let n_a2  =  1.0 - alpha / A
        b0[band]  = Float(n_b0  / a0)
        b1[band]  = Float(n_b12 / a0)
        b2[band]  = Float(n_b2  / a0)
        a1[band]  = Float(n_b12 / a0)
        a2[band]  = Float(n_a2  / a0)
    }
}

// MARK: - Audio Player Service

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

    private let eqState = EQState()

    private(set) var currentSpeed: Float = 1.0
    private(set) var isPitchPreserved: Bool = true
    var eqGains: [Float] { eqState.currentGains }

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

        setupEQTap(for: item)

        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard time.isValid, !time.isIndefinite else { return }
            Task { @MainActor [weak self] in self?.onTimeUpdate?(time.seconds) }
        }

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

        bufferObserver = item.observe(\.isPlaybackLikelyToKeepUp, options: [.new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                if item.isPlaybackLikelyToKeepUp { self?.onLoadingChange?(false) }
            }
        }

        rateObserver = player?.observe(\.rate, options: [.new]) { [weak self] player, _ in
            Task { @MainActor [weak self] in self?.onPlayStateChange?(player.rate > 0) }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: item, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.onPlayStateChange?(false)
                self?.onTrackEnd?()
            }
        }

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

    // MARK: - EQ

    func setEQGain(_ gain: Float, band: Int) {
        eqState.setGain(gain, band: band)
    }

    func applyQualityEQ(_ gains: [Float]) {}

    // MARK: - Private

    private func setupEQTap(for item: AVPlayerItem) {
        let state = eqState
        Task { @MainActor [weak self] in
            guard let self,
                  let tracks = try? await item.asset.loadTracks(withMediaType: .audio),
                  let track = tracks.first,
                  self.currentItem === item else { return }

            let retained = Unmanaged.passRetained(state).toOpaque()

            var callbacks = MTAudioProcessingTapCallbacks(
                version: kMTAudioProcessingTapCallbacksVersion_0,
                clientInfo: retained,
                init: { _, clientInfo, tapStorageOut in
                    tapStorageOut.pointee = clientInfo
                },
                finalize: { tap in
                    Unmanaged<EQState>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).release()
                },
                prepare: { tap, _, processingFormat in
                    Unmanaged<EQState>.fromOpaque(MTAudioProcessingTapGetStorage(tap))
                        .takeUnretainedValue()
                        .prepare(sampleRate: processingFormat.pointee.mSampleRate)
                },
                unprepare: { _ in },
                process: { tap, numberFrames, _, bufferListInOut, numberFramesOut, flagsOut in
                    guard MTAudioProcessingTapGetSourceAudio(
                        tap, numberFrames, bufferListInOut, flagsOut, nil, numberFramesOut
                    ) == noErr else { return }
                    let st = Unmanaged<EQState>.fromOpaque(MTAudioProcessingTapGetStorage(tap))
                        .takeUnretainedValue()
                    let frameCount = Int(numberFramesOut.pointee)
                    let buffers = UnsafeMutableAudioBufferListPointer(bufferListInOut)
                    for (ch, buf) in buffers.enumerated() {
                        guard let data = buf.mData else { continue }
                        let samples = data.assumingMemoryBound(to: Float.self)
                        st.process(buffer: samples, frameCount: frameCount, channel: ch)
                    }
                }
            )

            var tapRef: MTAudioProcessingTap?
            guard MTAudioProcessingTapCreate(
                kCFAllocatorDefault, &callbacks,
                kMTAudioProcessingTapCreationFlag_PostEffects, &tapRef
            ) == noErr, let tap = tapRef else { return }

            let params = AVMutableAudioMixInputParameters(track: track)
            params.audioTapProcessor = tap

            let mix = AVMutableAudioMix()
            mix.inputParameters = [params]
            item.audioMix = mix
        }
    }
}
