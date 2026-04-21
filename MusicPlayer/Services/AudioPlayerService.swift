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

    private let engine     = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    let eqNode             = AVAudioUnitEQ(numberOfBands: 5)
    private let timePitch  = AVAudioUnitTimePitch()

    private(set) var currentSpeed: Float  = 1.0
    private(set) var eqGains: [Float]     = [0, 0, 0, 0, 0]

    private var audioFile:     AVAudioFile?
    private var trackDuration: Double               = 0
    private var sampleOffset:  AVAudioFramePosition = 0
    private var isActive:      Bool                 = false
    private var lastKnownTime: Double               = 0
    private var downloadTask:  URLSessionDownloadTask?
    private var tempFileURL:   URL?
    private var timer:         Timer?
    private var generation:    Int = 0

    init() {
        setupEngine()
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.timer?.invalidate(); self?.timer = nil
            }
        }
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isActive else { return }
                self.startTimer()
            }
        }
    }

    private func activateAudioSession() {
        // Called lazily on first playback, not during app init.
        // Using a plain GCD call avoids Swift Concurrency actor
        // conflicts that can trigger SIGKILL during dyld startup.
        DispatchQueue.global(qos: .userInitiated).async {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try? AVAudioSession.sharedInstance().setActive(true)
        }
    }

    private func setupEngine() {
        engine.attach(playerNode)
        engine.attach(eqNode)
        engine.attach(timePitch)
        engine.connect(playerNode, to: eqNode,    format: nil)
        engine.connect(eqNode,    to: timePitch,  format: nil)
        engine.connect(timePitch, to: engine.mainMixerNode, format: nil)

        let freqs: [Float] = [60, 230, 910, 3600, 14000]
        for (i, f) in freqs.enumerated() {
            eqNode.bands[i].filterType = .parametric
            eqNode.bands[i].frequency  = f
            eqNode.bands[i].bandwidth  = 1.0
            eqNode.bands[i].gain       = 0
            eqNode.bands[i].bypass     = false
        }
        // Do NOT start the engine here — start lazily on first playback
        // so init() returns immediately and the first frame can render.
    }

    // MARK: - Playback

    func play(url: URL) {
        stop()
        onLoadingChange?(true)

        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mp3")
        tempFileURL = tmp

        downloadTask = URLSession.shared.downloadTask(with: url) { [weak self] local, _, err in
            guard let self, let local, err == nil else {
                Task { @MainActor [weak self] in self?.onLoadingChange?(false) }
                return
            }
            try? FileManager.default.moveItem(at: local, to: tmp)
            Task { @MainActor [weak self] in
                guard let self else { return }
                do    { try self.beginPlayback(from: tmp) }
                catch { self.onLoadingChange?(false) }
            }
        }
        downloadTask?.resume()
    }

    private func beginPlayback(from url: URL) throws {
        activateAudioSession()
        let file = try AVAudioFile(forReading: url)
        audioFile     = file
        trackDuration = Double(file.length) / file.processingFormat.sampleRate
        sampleOffset  = 0
        lastKnownTime = 0

        onDurationReady?(trackDuration)
        scheduleSegment(file: file, from: 0)
        if !engine.isRunning { try engine.start() }
        playerNode.play()
        timePitch.rate = currentSpeed
        isActive = true
        onLoadingChange?(false)
        onPlayStateChange?(true)
        startTimer()
    }

    private func scheduleSegment(file: AVAudioFile, from offset: AVAudioFramePosition) {
        generation += 1
        let gen = generation
        playerNode.stop()
        let remaining = AVAudioFrameCount(max(0, file.length - offset))
        guard remaining > 0 else { return }
        playerNode.scheduleSegment(file, startingFrame: offset, frameCount: remaining, at: nil) {
            [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.generation == gen else { return }
                self.isActive = false
                self.onPlayStateChange?(false)
                self.onTrackEnd?()
            }
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
        // Use .common so timer fires during scroll/interaction, not just when idle
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func tick() {
        guard let file = audioFile, file.processingFormat.sampleRate > 0 else { return }
        let sr = file.processingFormat.sampleRate
        if let nodeTime = playerNode.lastRenderTime,
           let pt = playerNode.playerTime(forNodeTime: nodeTime), pt.sampleTime >= 0 {
            let t = Double(sampleOffset) / sr + Double(pt.sampleTime) / sr
            lastKnownTime = min(t, trackDuration)
        }
        onTimeUpdate?(lastKnownTime)
    }

    func pause() {
        tick()
        playerNode.pause()
        isActive = false
        onPlayStateChange?(false)
    }

    func resume() {
        if !engine.isRunning { try? engine.start() }
        playerNode.play()
        timePitch.rate = currentSpeed
        isActive = true
        onPlayStateChange?(true)
    }

    func stop() {
        timer?.invalidate(); timer = nil
        downloadTask?.cancel(); downloadTask = nil
        generation += 1
        playerNode.stop()
        isActive = false
        if let u = tempFileURL { try? FileManager.default.removeItem(at: u); tempFileURL = nil }
        audioFile = nil; trackDuration = 0; sampleOffset = 0; lastKnownTime = 0
        onPlayStateChange?(false); onTimeUpdate?(0); onDurationReady?(0)
    }

    func seek(to seconds: Double) {
        guard let file = audioFile, file.processingFormat.sampleRate > 0 else { return }
        let sr = file.processingFormat.sampleRate
        sampleOffset  = max(0, min(AVAudioFramePosition(seconds * sr), file.length - 1))
        lastKnownTime = Double(sampleOffset) / sr
        let wasPlaying = isActive
        scheduleSegment(file: file, from: sampleOffset)
        if !engine.isRunning { try? engine.start() }
        playerNode.play()
        timePitch.rate = currentSpeed
        if !wasPlaying { playerNode.pause() }
    }

    func setSpeed(_ rate: Float) {
        currentSpeed   = rate
        timePitch.rate = rate
    }

    func setEQGain(_ gain: Float, band: Int) {
        guard band < eqNode.bands.count else { return }
        eqNode.bands[band].gain = gain
        if band < eqGains.count { eqGains[band] = gain }
    }
}
