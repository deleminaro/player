import Foundation

// MARK: - Track source

enum TrackSource: String, Codable {
    case soundcloud, spotify
}

// MARK: - Track

struct Track: Identifiable, Hashable {
    let id: Int
    let title: String
    let username: String
    let artworkURL: String?
    let duration: Int          // milliseconds
    let permalinkURL: String
    let media: Media?
    let source: TrackSource
    let previewURL: String?    // Spotify 30s MP3 preview
    let spotifyURI: String?

    init(id: Int, title: String, username: String, artworkURL: String?,
         duration: Int, permalinkURL: String, media: Media?,
         source: TrackSource = .soundcloud, previewURL: String? = nil,
         spotifyURI: String? = nil) {
        self.id           = id
        self.title        = title
        self.username     = username
        self.artworkURL   = artworkURL
        self.duration     = duration
        self.permalinkURL = permalinkURL
        self.media        = media
        self.source       = source
        self.previewURL   = previewURL
        self.spotifyURI   = spotifyURI
    }

    var durationFormatted: String {
        let s = duration / 1000
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    var highResArtworkURL: String? {
        artworkURL?
            .replacingOccurrences(of: "-large.", with: "-t500x500.")
            .replacingOccurrences(of: "-t300x300.", with: "-t500x500.")
    }

    // Highest quality variant for lock screen (SoundCloud originals are full-resolution)
    var lockScreenArtworkURL: String? {
        artworkURL?
            .replacingOccurrences(of: "-large.", with: "-original.")
            .replacingOccurrences(of: "-t300x300.", with: "-original.")
            .replacingOccurrences(of: "-t500x500.", with: "-original.")
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

        /// Picks the best transcoding for a given quality tier.
        ///
        /// SoundCloud returns up to three transcodings per track:
        ///   • audio/ogg; codecs="opus"  + hls        (Opus, best codec)
        ///   • audio/mpeg                + hls        (MP3 via HLS)
        ///   • audio/mpeg                + progressive (direct MP3 download)
        ///
        /// AVPlayer handles all three natively, so we route high-quality tiers
        /// to Opus/HLS and lower tiers to MP3/progressive.
        func transcoding(for quality: AudioQuality) -> Transcoding? {
            let opus       = transcodings.first { $0.format.mimeType.contains("opus") }
            let hlsMp3     = transcodings.first { $0.format.protocolType == "hls" && $0.format.mimeType.contains("mpeg") }
            let progressive = transcodings.first { $0.format.protocolType == "progressive" }
            switch quality {
            case .lossless: return opus ?? progressive ?? hlsMp3 ?? transcodings.first
            case .high:     return opus ?? progressive ?? hlsMp3 ?? transcodings.first
            case .medium:   return progressive ?? hlsMp3 ?? opus ?? transcodings.first
            case .low:      return hlsMp3 ?? progressive ?? opus ?? transcodings.first
            }
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
        case id, title, media, source, previewURL, spotifyURI
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
        source       = (try? c.decode(TrackSource.self, forKey: .source)) ?? .soundcloud
        previewURL   = try? c.decodeIfPresent(String.self, forKey: .previewURL)
        spotifyURI   = try? c.decodeIfPresent(String.self, forKey: .spotifyURI)

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
        try c.encode(source,       forKey: .source)
        try c.encodeIfPresent(previewURL, forKey: .previewURL)
        try c.encodeIfPresent(spotifyURI, forKey: .spotifyURI)

        var u = c.nestedContainer(keyedBy: UserKeys.self, forKey: .user)
        try u.encode(username, forKey: .username)
    }
}

// MARK: - Supporting types

enum PlayerState {
    case idle, loading, playing, paused
}

enum RepeatMode: String {
    case off, one, all

    var next: RepeatMode {
        switch self {
        case .off: return .one
        case .one: return .all
        case .all: return .off
        }
    }

    var icon: String {
        switch self {
        case .off: return "repeat"
        case .one: return "repeat.1"
        case .all: return "repeat"
        }
    }
}

struct QueueItem: Identifiable {
    let id   = UUID()
    let track: Track
}

// MARK: - Local Playlist (user-created, stored on device)

struct LocalPlaylist: Identifiable, Codable, Hashable {
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
    let permalink: String?      // URL slug, e.g. "delami-257483686"

    var formattedFollowers: String {
        guard let n = followersCount else { return "" }
        if n >= 1_000_000 { return String(format: "%.1fM followers", Double(n) / 1_000_000) }
        if n >= 1_000     { return String(format: "%.0fK followers", Double(n) / 1_000) }
        return "\(n) followers"
    }

    enum CodingKeys: String, CodingKey {
        case id, username, permalink
        case avatarURL      = "avatar_url"
        case followersCount = "followers_count"
    }
}
