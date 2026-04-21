import Foundation

enum Constants {
    // MARK: - Replace these with your actual keys before running
    static var soundcloudClientID = "yNSW5UvBmb1A5j7qPUtIMuB9Itx3jsOC"
    static var geniusToken        = "rWlzywghaCWdSYpBF1OJQlMsiXghcIGb1uX0UmT8nhBMYBFUNL8LVhXs4Fhwg-_N"

    enum SoundCloud {
        static let baseURL    = "https://api-v2.soundcloud.com"
        static let searchLimit = 50
    }

    enum Genius {
        static let baseURL = "https://api.genius.com"
    }
}
