import Foundation
import SpotifyiOS
import UIKit

/// Wraps SPTAppRemote to stream full Spotify tracks through the Spotify app.
/// Requires SpotifyiOS Swift Package — add via Xcode: File → Add Package Dependencies
/// URL: https://github.com/spotify/ios-sdk
///
/// Audio comes from the Spotify app, not AVPlayer.
/// SPTAppRemotePlayerState.playbackPosition is in milliseconds.
@MainActor
final class SpotifyRemoteService: NSObject, ObservableObject {
    static let shared = SpotifyRemoteService()

    // MARK: - Callbacks (set by PlayerViewModel)

    var onPlayStateChange:  ((Bool) -> Void)?
    var onTimeUpdate:       ((Double) -> Void)?
    var onDurationReady:    ((Double) -> Void)?
    var onTrackEnd:         (() -> Void)?
    var onConnectionFailed: (() -> Void)?

    // MARK: - Internal state

    private var pendingURI:      String?
    private var positionTimer:   Timer?
    private var lastPositionSec: Double = 0
    private var trackDurationSec: Double = 0

    // MARK: - App Remote

    private(set) lazy var appRemote: SPTAppRemote = {
        let config = SPTConfiguration(
            clientID: Constants.spotifyClientID,
            redirectURL: URL(string: "postor://spotify-callback")!
        )
        let remote = SPTAppRemote(configuration: config, logLevel: .none)
        remote.delegate = self
        return remote
    }()

    var isConnected: Bool { appRemote.isConnected }

    // MARK: - Playback control

    /// Play a full Spotify track. accessToken must be the PKCE user access token.
    func play(uri: String, accessToken: String) {
        appRemote.connectionParameters.accessToken = accessToken
        if appRemote.isConnected {
            appRemote.playerAPI?.play(uri, callback: nil)
        } else if UIApplication.shared.canOpenURL(URL(string: "spotify:")!) {
            // authorizeAndPlayURI opens Spotify, starts the track, then Spotify
            // redirects to postor://spotify-callback — handleCallback() will connect
            // App Remote so we can control playback. Don't queue pendingURI since
            // Spotify is already playing the track before the callback fires.
            pendingURI = nil
            appRemote.authorizeAndPlayURI(uri)
        } else {
            onConnectionFailed?()
        }
    }

    func pause() {
        guard appRemote.isConnected else { return }
        appRemote.playerAPI?.pause(nil)
    }

    func resume() {
        guard appRemote.isConnected else { return }
        appRemote.playerAPI?.resume(nil)
    }

    /// positionSec: seconds from the start of the track
    func seek(to positionSec: Double) {
        guard appRemote.isConnected else { return }
        appRemote.playerAPI?.seek(toPosition: Int(positionSec * 1000), callback: nil)
        lastPositionSec = positionSec
        onTimeUpdate?(positionSec)
    }

    func stop() {
        stopPositionTimer()
        if appRemote.isConnected {
            appRemote.playerAPI?.pause(nil)
        }
    }

    func disconnect() {
        stopPositionTimer()
        if appRemote.isConnected { appRemote.disconnect() }
    }

    /// Called from app's onOpenURL when Spotify redirects back after authorisation.
    func handleCallback(url: URL) {
        let params = appRemote.authorizationParameters(from: url)
        if let token = params?[SPTAppRemoteAccessTokenKey] as? String {
            appRemote.connectionParameters.accessToken = token
            appRemote.connect()
        }
    }

    // MARK: - Position timer (interpolates between SDK state callbacks)

    private func startPositionTimer() {
        stopPositionTimer()
        positionTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.lastPositionSec += 0.5
                self.onTimeUpdate?(self.lastPositionSec)
                if self.trackDurationSec > 0, self.lastPositionSec >= self.trackDurationSec - 0.3 {
                    self.stopPositionTimer()
                    self.onTrackEnd?()
                }
            }
        }
    }

    private func stopPositionTimer() {
        positionTimer?.invalidate()
        positionTimer = nil
    }
}

// MARK: - SPTAppRemoteDelegate

extension SpotifyRemoteService: SPTAppRemoteDelegate {
    nonisolated func appRemoteDidEstablishConnection(_ remote: SPTAppRemote) {
        Task { @MainActor in
            remote.playerAPI?.delegate = self
            remote.playerAPI?.subscribe(toPlayerState: { _, error in
                if let error { AppLogger.shared.log("subscribe error: \(error.localizedDescription)", category: "Spotify") }
            })
            if let uri = self.pendingURI {
                self.pendingURI = nil
                remote.playerAPI?.play(uri, callback: nil)
            }
        }
    }

    nonisolated func appRemote(_ remote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        Task { @MainActor in
            AppLogger.shared.log("Connection failed: \(error?.localizedDescription ?? "unknown")", category: "Spotify")
            self.stopPositionTimer()
            self.onConnectionFailed?()
        }
    }

    nonisolated func appRemote(_ remote: SPTAppRemote, didDisconnectWithError error: Error?) {
        Task { @MainActor in
            self.stopPositionTimer()
        }
    }
}

// MARK: - SPTAppRemotePlayerStateDelegate

extension SpotifyRemoteService: SPTAppRemotePlayerStateDelegate {
    nonisolated func playerStateDidChange(_ state: SPTAppRemotePlayerState) {
        Task { @MainActor in
            let isPlaying = !state.isPaused
            // playbackPosition and track.duration are both in milliseconds
            let positionSec = Double(state.playbackPosition) / 1000.0
            let durationSec = Double(state.track.duration) / 1000.0

            self.lastPositionSec = positionSec
            self.onTimeUpdate?(positionSec)

            if durationSec != self.trackDurationSec, durationSec > 0 {
                self.trackDurationSec = durationSec
                self.onDurationReady?(durationSec)
            }

            self.onPlayStateChange?(isPlaying)

            if isPlaying {
                self.startPositionTimer()
            } else {
                self.stopPositionTimer()
                if durationSec > 0, positionSec >= durationSec - 1.0 {
                    self.onTrackEnd?()
                }
            }
        }
    }
}
