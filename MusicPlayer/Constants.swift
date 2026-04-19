import Foundation

enum Constants {
    // MARK: - Replace these with your actual keys before running
    static var soundcloudClientID = "f6k2kBKdKxsBaJCEeHQHScqQLINy5UUN"
    static var geniusToken        = "YOUR_GENIUS_BEARER_TOKEN"

    enum SoundCloud {
        static let baseURL    = "https://api-v2.soundcloud.com"
        static let searchLimit = 20
    }

    enum Genius {
        static let baseURL = "https://api.genius.com"
    }
}
