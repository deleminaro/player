import ActivityKit
import Foundation

struct MusicActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var title:      String
        var artist:     String
        var artworkURL: String
        var isPlaying:  Bool
        var progress:   Double
    }
}
