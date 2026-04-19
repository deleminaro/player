import Foundation

enum Constants {
    // MARK: - Replace these with your actual keys before running
    static var soundcloudClientID = "YOUR_SOUNDCLOUD_CLIENT_ID"
    static var geniusToken        = "YOUR_GENIUS_BEARER_TOKEN"

    enum SoundCloud {
        static let baseURL    = "https://api-v2.soundcloud.com"
        static let searchLimit = 20
    }

    enum Genius {
        static let baseURL = "https://api.genius.com"
    }
}
