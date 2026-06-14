import Foundation

enum Constants {
    static let soundcloudClientID = "yNSW5UvBmb1A5j7qPUtIMuB9Itx3jsOC"
    static let geniusToken        = "rWlzywghaCWdSYpBF1OJQlMsiXghcIGb1uX0UmT8nhBMYBFUNL8LVhXs4Fhwg-_N"
    static let spotifyClientID    = "c2f4afcc27a64caca6ae4f413e1f7903"
    static let backendAPIKey      = ""

    enum SoundCloud {
        static let baseURL     = "https://api-v2.soundcloud.com"
        static let searchLimit = 100
    }

    enum Genius {
        static let baseURL = "https://api.genius.com"
    }

    enum Spotify {
        static let baseURL   = "https://api.spotify.com/v1"
        static let tokenURL  = "https://accounts.spotify.com/api/token"
        static let searchLimit = 20
    }

    enum Backend {
        static let baseURL = ""
    }
}
