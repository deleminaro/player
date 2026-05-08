import Foundation

// Audio fallback via public Invidious instances (open-source YouTube frontend).
// Used when SoundCloud cannot serve a track (404 / removed / geo-blocked).
actor YouTubeService {
    static let shared = YouTubeService()

    private let instances = [
        "https://inv.nadeko.net",
        "https://invidious.nerdvpn.de",
        "https://invidious.privacyredirect.com",
        "https://yt.cdaut.de",
    ]

    /// Searches all instances in order and returns the first working audio stream URL.
    func searchAudioURL(query: String) async throws -> URL {
        for instance in instances {
            if let url = try? await fetch(from: instance, query: query) { return url }
        }
        throw YTError.notFound
    }

    private func fetch(from instance: String, query: String) async throws -> URL {
        // 1. Search for the video
        var searchComps = URLComponents(string: "\(instance)/api/v1/search")!
        searchComps.queryItems = [
            URLQueryItem(name: "q",    value: query),
            URLQueryItem(name: "type", value: "video"),
        ]
        guard let searchURL = searchComps.url else { throw YTError.notFound }
        let (searchData, searchResp) = try await URLSession.shared.data(from: searchURL)
        guard (searchResp as? HTTPURLResponse)?.statusCode == 200 else { throw YTError.notFound }
        let results = try JSONDecoder().decode([SearchResult].self, from: searchData)
        guard let videoId = results.first?.videoId else { throw YTError.notFound }

        // 2. Fetch adaptive formats for the video
        let videoURL = URL(string: "\(instance)/api/v1/videos/\(videoId)")!
        let (videoData, videoResp) = try await URLSession.shared.data(from: videoURL)
        guard (videoResp as? HTTPURLResponse)?.statusCode == 200 else { throw YTError.notFound }
        let detail = try JSONDecoder().decode(VideoDetail.self, from: videoData)

        // Prefer M4A (compatible with AVPlayer), fall back to any audio stream
        let audioStreams = detail.adaptiveFormats.filter { $0.type.hasPrefix("audio/") }
        let stream = audioStreams.first { $0.type.contains("mp4") } ?? audioStreams.first
        guard let streamURL = stream.flatMap({ URL(string: $0.url) }) else { throw YTError.notFound }
        return streamURL
    }

    // MARK: - Models

    private struct SearchResult: Decodable {
        let videoId: String
    }

    private struct VideoDetail: Decodable {
        let adaptiveFormats: [AdaptiveFormat]
        struct AdaptiveFormat: Decodable {
            let url: String
            let type: String
        }
    }

    // MARK: - Errors

    enum YTError: LocalizedError {
        case notFound
        var errorDescription: String? { "YouTube: no audio stream found for this track." }
    }
}
