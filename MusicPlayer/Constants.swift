import Foundation

enum Constants {
    // MARK: - Replace these with your actual keys before running
    static var soundcloudClientID  = "yNSW5UvBmb1A5j7qPUtIMuB9Itx3jsOC"
    static var geniusToken         = "rWlzywghaCWdSYpBF1OJQlMsiXghcIGb1uX0UmT8nhBMYBFUNL8LVhXs4Fhwg-_N"
    static var spotifyClientID     = "c2f4afcc27a64caca6ae4f413e1f7903"
    static var spotifyClientSecret = "8f90353289b843b6b1931ecd8ff7ad79"

    enum SoundCloud {
        static let baseURL    = "https://api-v2.soundcloud.com"
        static let searchLimit = 50
    }

    enum Genius {
        static let baseURL = "https://api.genius.com"
    }

    enum Spotify {
        static let baseURL    = "https://api.spotify.com/v1"
        static let tokenURL   = "https://accounts.spotify.com/api/token"
        static let searchLimit = 20
    }
}
