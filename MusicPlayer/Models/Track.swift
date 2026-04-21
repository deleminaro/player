import Foundation

// MARK: - Track

struct Track: Identifiable, Hashable {
    let id: Int
    let title: String
    let username: String
    let artworkURL: String?
    let duration: Int          // milliseconds
    let permalinkURL: String
    let media: Media?

    var durationFormatted: String {
        let s = duration / 1000
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    var highResArtworkURL: String? {
        artworkURL?
            .replacingOccurrences(of: "-large.", with: "-t500x500.")
            .replacingOccurrences(of: "-t300x300.", with: "-t500x500.")
    }

    var thumbnailArtworkURL: String? {
        artworkURL?
            .replacingOccurrences(of: "-t500x500.", with: "-t300x300.")
            .replacingOccurrences(of: "-large.", with: "-t300x300.")
    }

    // MARK: - Nested types

    struct Media: Codable, Hashable {
        let transcodings: [Transcoding]

        var progressiveTranscoding: Transcoding? {
            transcodings.first { $0.format.protocolType == "progressive" }
                ?? transcodings.first { $0.format.mimeType.contains("mpeg") }
                ?? transcodings.first
        }
    }

    struct Transcoding: Codable, Hashable {
        let url: String
        let format: Format

        struct Format: Codable, Hashable {
            let mimeType: String
            let protocolType: String

            enum CodingKeys: String, CodingKey {
                case mimeType    = "mime_type"
                case protocolType = "protocol"
            }
        }
    }
}

// MARK: - Codable

extension Track: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, title, media
        case artworkURL   = "artwork_url"
        case duration
        case permalinkURL = "permalink_url"
        case user
    }

    private enum UserKeys: String, CodingKey {
        case username
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id           = try c.decode(Int.self,    forKey: .id)
        title        = try c.decode(String.self, forKey: .title)
        artworkURL   = try c.decodeIfPresent(String.self, forKey: .artworkURL)
        duration     = try c.decode(Int.self,    forKey: .duration)
        permalinkURL = try c.decode(String.self, forKey: .permalinkURL)
        media        = try c.decodeIfPresent(Media.self, forKey: .media)

        let u  = try c.nestedContainer(keyedBy: UserKeys.self, forKey: .user)
        username = try u.decode(String.self, forKey: .username)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,           forKey: .id)
        try c.encode(title,        forKey: .title)
        try c.encodeIfPresent(artworkURL,   forKey: .artworkURL)
        try c.encode(duration,     forKey: .duration)
        try c.encode(permalinkURL, forKey: .permalinkURL)
        try c.encodeIfPresent(media, forKey: .media)

        var u = c.nestedContainer(keyedBy: UserKeys.self, forKey: .user)
        try u.encode(username, forKey: .username)
    }
}

// MARK: - Supporting types

enum PlayerState {
    case idle, loading, playing, paused
}

struct QueueItem: Identifiable {
    let id   = UUID()
    let track: Track
}

// MARK: - Local Playlist (user-created, stored on device)

struct LocalPlaylist: Identifiable, Codable {
    let id: UUID
    var name: String
    var tracks: [Track]
    let createdAt: Date

    init(name: String) {
        id        = UUID()
        self.name = name
        tracks    = []
        createdAt = Date()
    }

    var thumbnailArtworkURL: String? { tracks.first?.thumbnailArtworkURL }
    var mosaicURLs: [String] { tracks.prefix(4).compactMap { $0.thumbnailArtworkURL } }
}

// MARK: - SoundCloud Playlist

struct SCPlaylist: Identifiable {
    let id: Int
    let title: String
    let username: String
    let artworkURL: String?
    let trackCount: Int

    var thumbnailArtworkURL: String? {
        artworkURL?
            .replacingOccurrences(of: "-large.",   with: "-t300x300.")
            .replacingOccurrences(of: "-t500x500.", with: "-t300x300.")
    }
}

extension SCPlaylist: Decodable {
    private enum CK: String, CodingKey { case id, title, user
        case artworkURL = "artwork_url"; case trackCount = "track_count" }
    private enum UK: String, CodingKey { case username }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CK.self)
        id         = try c.decode(Int.self, forKey: .id)
        title      = try c.decode(String.self, forKey: .title)
        artworkURL = try c.decodeIfPresent(String.self, forKey: .artworkURL)
        trackCount = (try? c.decode(Int.self, forKey: .trackCount)) ?? 0
        let u = try c.nestedContainer(keyedBy: UK.self, forKey: .user)
        username   = try u.decode(String.self, forKey: .username)
    }
}

// MARK: - SoundCloud Artist

struct SCArtist: Identifiable, Decodable {
    let id: Int
    let username: String
    let avatarURL: String?
    let followersCount: Int?

    var formattedFollowers: String {
        guard let n = followersCount else { return "" }
        if n >= 1_000_000 { return String(format: "%.1fM followers", Double(n) / 1_000_000) }
        if n >= 1_000     { return String(format: "%.0fK followers", Double(n) / 1_000) }
        return "\(n) followers"
    }

    enum CodingKeys: String, CodingKey {
        case id, username
        case avatarURL      = "avatar_url"
        case followersCount = "followers_count"
    }
}
