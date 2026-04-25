import Foundation

enum Constants {
    // MARK: - Replace these with your actual keys before running
    static var soundcloudClientID  = "yNSW5UvBmb1A5j7qPUtIMuB9Itx3jsOC"
    static var geniusToken         = "rWlzywghaCWdSYpBF1OJQlMsiXghcIGb1uX0UmT8nhBMYBFUNL8LVhXs4Fhwg-_N"
    static var spotifyClientID     = "0f013be207984993b94822b2e7085b68"
    static var spotifyClientSecret = "8570bb3671f64588b7361603b40d8bd6"

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
        static let searchLimit = 50
    }
}
