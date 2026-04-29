import Foundation

// Keys are loaded from Info.plist, which is populated at build time
// from Secrets.xcconfig (gitignored). Nothing sensitive is hardcoded here.
//
// To set up locally:
//   cp MusicPlayer/Config/Secrets.xcconfig.example MusicPlayer/Config/Secrets.xcconfig
//   Fill in your values. Never commit Secrets.xcconfig.

enum Constants {

    // MARK: - Bundle-loaded keys (set via xcconfig → Info.plist)

    static let spotifyClientID:  String = bundleString("SpotifyClientID")
    static let soundcloudClientID: String = bundleString("SoundCloudClientID")

    // The key this app uses to authenticate with *our own* backend.
    // The backend holds Genius tokens, SoundCloud client_id, etc.
    static let backendAPIKey: String = bundleString("BackendAPIKey")

    // MARK: - URLs (non-sensitive, committed in Config.xcconfig)

    enum SoundCloud {
        static let baseURL     = "https://api-v2.soundcloud.com"
        static let searchLimit = 100
    }

    enum Genius {
        // Requests go through our backend proxy — no token on device
        static let baseURL = "https://api.genius.com"
    }

    enum Spotify {
        static let baseURL   = "https://api.spotify.com/v1"
        static let tokenURL  = "https://accounts.spotify.com/api/token"
        static let searchLimit = 20
        // No client_secret — PKCE doesn't require it on device
    }

    enum Backend {
        static let baseURL: String = bundleString("BackendBaseURL",
                                                   fallback: "https://api.yourbackend.com")
    }

    // MARK: - Helper

    private static func bundleString(_ key: String, fallback: String = "") -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty,
              !value.hasPrefix("$(")   // catch un-expanded xcconfig placeholders
        else {
            #if DEBUG
            print("[Constants] WARNING: '\(key)' not set in Info.plist / xcconfig")
            #endif
            return fallback
        }
        return value
    }
}
