import Foundation

actor SoundCloudService {
    static let shared = SoundCloudService()

    private let base = Constants.SoundCloud.baseURL

    // MARK: - Search

    func search(query: String, offset: Int = 0) async throws -> [Track] {
        try await searchEndpoint("/search/tracks", query: query, offset: offset,
                                 as: SearchResponse<Track>.self).collection
    }

    func searchPlaylists(query: String, offset: Int = 0) async throws -> [SCPlaylist] {
        try await searchEndpoint("/search/playlists", query: query, offset: offset,
                                 as: SearchResponse<SCPlaylist>.self).collection
    }

    func searchAlbums(query: String, offset: Int = 0) async throws -> [SCPlaylist] {
        try await searchEndpoint("/search/albums", query: query, offset: offset,
                                 as: SearchResponse<SCPlaylist>.self).collection
    }

    func searchArtists(query: String, offset: Int = 0) async throws -> [SCArtist] {
        try await searchEndpoint("/search/users", query: query, offset: offset,
                                 as: SearchResponse<SCArtist>.self).collection
    }

    func fetchUserTracks(userID: Int, limit: Int = 10) async throws -> [Track] {
        var comps = URLComponents(string: "\(base)/users/\(userID)/tracks")!
        comps.queryItems = [
            URLQueryItem(name: "client_id",           value: Constants.soundcloudClientID),
            URLQueryItem(name: "limit",               value: "\(limit)"),
            URLQueryItem(name: "linked_partitioning", value: "1"),
        ]
        guard let url = comps.url else { throw SCError.invalidURL }
        let (data, resp) = try await URLSession.shared.data(from: url)
        try validate(resp)
        return try JSONDecoder().decode(SearchResponse<Track>.self, from: data).collection
    }

    func fetchUserPlaylists(userID: Int) async throws -> [SCPlaylist] {
        var comps = URLComponents(string: "\(base)/users/\(userID)/playlists")!
        comps.queryItems = [
            URLQueryItem(name: "client_id",           value: Constants.soundcloudClientID),
            URLQueryItem(name: "linked_partitioning", value: "1"),
        ]
        guard let url = comps.url else { throw SCError.invalidURL }
        let (data, resp) = try await URLSession.shared.data(from: url)
        try validate(resp)
        return try JSONDecoder().decode(SearchResponse<SCPlaylist>.self, from: data).collection
    }

    func fetchPlaylistTracks(id: Int) async throws -> [Track] {
        var comps = URLComponents(string: "\(base)/playlists/\(id)")!
        comps.queryItems = [URLQueryItem(name: "client_id", value: Constants.soundcloudClientID)]
        guard let url = comps.url else { throw SCError.invalidURL }
        let (data, resp) = try await URLSession.shared.data(from: url)
        try validate(resp)
        // Stubs only guarantee `id` — decode just IDs, then batch-fetch full track data
        struct IDOnly: Decodable { let id: Int }
        struct PlaylistDetail: Decodable { let tracks: [IDOnly]? }
        let ids = (try? JSONDecoder().decode(PlaylistDetail.self, from: data))?.tracks?.map { $0.id } ?? []
        guard !ids.isEmpty else { return [] }
        return try await fetchTracksByIDs(ids)
    }

    func fetchTracksByIDs(_ ids: [Int]) async throws -> [Track] {
        guard !ids.isEmpty else { return [] }
        var result: [Track] = []
        let chunks = stride(from: 0, to: ids.count, by: 50).map { Array(ids[$0..<min($0+50, ids.count)]) }
        for chunk in chunks {
            var comps = URLComponents(string: "\(base)/tracks")!
            comps.queryItems = [
                URLQueryItem(name: "ids",       value: chunk.map(String.init).joined(separator: ",")),
                URLQueryItem(name: "client_id", value: Constants.soundcloudClientID),
            ]
            guard let url = comps.url else { continue }
            let (data, resp) = try await URLSession.shared.data(from: url)
            try validate(resp)
            let tracks = try JSONDecoder().decode([Track].self, from: data)
            result.append(contentsOf: tracks)
        }
        return result
    }

    private func searchEndpoint<T: Decodable>(_ path: String, query: String, offset: Int,
                                              as type: T.Type) async throws -> T {
        var comps = URLComponents(string: "\(base)\(path)")!
        comps.queryItems = [
            URLQueryItem(name: "q",         value: query),
            URLQueryItem(name: "client_id", value: Constants.soundcloudClientID),
            URLQueryItem(name: "limit",     value: "\(Constants.SoundCloud.searchLimit)"),
            URLQueryItem(name: "offset",    value: "\(offset)"),
        ]
        guard let url = comps.url else { throw SCError.invalidURL }
        let (data, resp) = try await URLSession.shared.data(from: url)
        try validate(resp)
        return try JSONDecoder().decode(type, from: data)
    }

    // MARK: - User resolve & likes import

    /// Resolves a SoundCloud username/URL to a user object.
    /// Uses search + permalink matching (the /resolve endpoint is restricted for this client_id).
    func resolveUser(permalink: String) async throws -> SCArtist {
        // Extract clean permalink slug from any input form:
        // "delami", "@delami", "soundcloud.com/delami/likes?...", full URL, etc.
        var input = permalink
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://",  with: "")
            .replacingOccurrences(of: "www.",      with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "@/ "))

        if input.hasPrefix("soundcloud.com/") {
            input = String(input.dropFirst("soundcloud.com/".count))
        }
        // Take only the first path component (strips /likes, /tracks, query strings, etc.)
        let slug = input.components(separatedBy: "/").first
            .flatMap { $0.components(separatedBy: "?").first } ?? input

        guard !slug.isEmpty else { throw SCError.invalidURL }

        // Search for matching users and pick the one whose permalink matches exactly.
        // Falls back to first result if no exact permalink match (handles display-name searches).
        let results = try await searchArtists(query: slug)
        if let exact = results.first(where: { $0.permalink?.lowercased() == slug }) {
            return exact
        }
        if let first = results.first { return first }
        throw SCError.badResponse(404)
    }

    /// Fetches all liked tracks for a user (paginates until empty or 500 tracks).
    func fetchUserLikes(userID: Int) async throws -> [Track] {
        var all: [Track] = []
        var nextURLStr: String? = "\(base)/users/\(userID)/likes/tracks"
        while let urlStr = nextURLStr, all.count < 500 {
            var comps = URLComponents(string: urlStr)!
            var items = comps.queryItems ?? []
            func setIfMissing(_ name: String, _ value: String) {
                if !items.contains(where: { $0.name == name }) {
                    items.append(URLQueryItem(name: name, value: value))
                }
            }
            setIfMissing("client_id",           Constants.soundcloudClientID)
            setIfMissing("limit",               "200")
            setIfMissing("linked_partitioning", "1")
            comps.queryItems = items
            guard let url = comps.url else { break }
            let (data, resp) = try await URLSession.shared.data(from: url)
            try validate(resp)
            struct LikesPage: Decodable {
                let collection: [Track]
                // swiftlint:disable:next identifier_name
                let next_href: String?
            }
            let page = try JSONDecoder().decode(LikesPage.self, from: data)
            all.append(contentsOf: page.collection)
            nextURLStr = page.collection.isEmpty ? nil : page.next_href
        }
        return all
    }

    // MARK: - Stream URL resolution

    /// Hit the transcoding URL → get the real CDN stream URL.
    func resolveStreamURL(transcodingURL: String) async throws -> URL {
        var comps = URLComponents(string: transcodingURL)!
        var items = comps.queryItems ?? []
        items.append(URLQueryItem(name: "client_id", value: Constants.soundcloudClientID))
        comps.queryItems = items
        guard let url = comps.url else { throw SCError.invalidURL }

        let (data, resp) = try await URLSession.shared.data(from: url)
        try validate(resp)

        let result = try JSONDecoder().decode(StreamURLResponse.self, from: data)
        guard let streamURL = URL(string: result.url) else { throw SCError.invalidURL }
        return streamURL
    }

    // MARK: - Helpers

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw SCError.badResponse(nil) }
        guard (200..<300).contains(http.statusCode) else {
            AppLogger.shared.log("HTTP \(http.statusCode) from \(http.url?.host ?? "?")", category: "Network")
            throw SCError.badResponse(http.statusCode)
        }
    }

    // MARK: - Private models

    private struct SearchResponse<T: Decodable>: Decodable {
        let collection: [T]
    }

    private struct StreamURLResponse: Decodable {
        let url: String
    }

    // MARK: - Errors

    enum SCError: LocalizedError {
        case invalidURL
        case badResponse(Int?)

        var errorDescription: String? {
            switch self {
            case .invalidURL:          return "Invalid SoundCloud URL."
            case .badResponse(let code):
                switch code {
                case 401:  return "SoundCloud: unauthorized (client_id expired or invalid)."
                case 403:  return "SoundCloud: access forbidden — track may be private or geo-blocked."
                case 404:  return "SoundCloud: track not found."
                case 429:  return "SoundCloud: rate limited — too many requests."
                case let s?: return "SoundCloud returned HTTP \(s)."
                case nil:  return "SoundCloud returned an unexpected response."
                }
            }
        }
    }
}
