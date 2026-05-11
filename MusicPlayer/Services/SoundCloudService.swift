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

    /// Resolves a SoundCloud username/URL to a user object by scraping the public profile page.
    /// All /resolve API endpoints are blocked for this client_id, so we extract the user ID
    /// from the embedded hydration JSON on soundcloud.com instead.
    func resolveUser(permalink: String) async throws -> SCArtist {
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
        // Take only the first path component, strip query strings
        let slug = input.components(separatedBy: "/").first
            .flatMap { $0.components(separatedBy: "?").first } ?? input
        guard !slug.isEmpty else { throw SCError.invalidURL }

        AppLogger.shared.log("Resolving SC user: \(slug)", category: "Network")
        return try await resolveUserFromPage(slug: slug)
    }

    private func resolveUserFromPage(slug: String) async throws -> SCArtist {
        // Try the likes page first (most common shared URL), then the plain profile page
        for path in ["\(slug)/likes", slug] {
            guard let pageURL = URL(string: "https://soundcloud.com/\(path)") else { continue }
            var request = URLRequest(url: pageURL)
            request.setValue(
                "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
                forHTTPHeaderField: "User-Agent"
            )
            guard let (data, _) = try? await URLSession.shared.data(for: request),
                  let html = String(data: data, encoding: .utf8) else {
                AppLogger.shared.log("Failed to fetch page: \(path)", category: "Network")
                continue
            }
            AppLogger.shared.log("Fetched \(path), length=\(html.count)", category: "Network")
            // SoundCloud embeds "soundcloud:users:XXXXXXX" in the page hydration JSON
            guard let urnRange = html.range(of: #"soundcloud:users:(\d+)"#, options: .regularExpression) else {
                AppLogger.shared.log("No user urn in: \(path)", category: "Network")
                continue
            }
            let urnFragment = String(html[urnRange])
            guard let idStr = urnFragment.components(separatedBy: ":").last,
                  let userID = Int(idStr) else { continue }
            AppLogger.shared.log("Extracted user ID \(userID) from \(path)", category: "Network")
            // Try to get the full user object; fall back to a stub (only id is needed for fetchUserLikes)
            var comps = URLComponents(string: "\(base)/users/\(userID)")!
            comps.queryItems = [URLQueryItem(name: "client_id", value: Constants.soundcloudClientID)]
            if let apiURL = comps.url,
               let (userData, userResp) = try? await URLSession.shared.data(from: apiURL),
               (userResp as? HTTPURLResponse)?.statusCode == 200,
               let artist = try? JSONDecoder().decode(SCArtist.self, from: userData) {
                return artist
            }
            return SCArtist(id: userID, username: slug, avatarURL: nil, followersCount: nil, permalink: slug)
        }
        AppLogger.shared.log("Could not resolve user: \(slug)", category: "Network")
        throw SCError.badResponse(404)
    }

    /// Fetches all liked tracks for a user (paginates until empty or 500 tracks).
    /// Tries /likes/tracks first, falls back to /likes (mixed likes endpoint).
    func fetchUserLikes(userID: Int) async throws -> [Track] {
        AppLogger.shared.log("Fetching likes for user \(userID)", category: "Network")
        do {
            let tracks = try await paginateLikes(
                startURL: "\(base)/users/\(userID)/likes/tracks",
                decode: { data in
                    struct Page: Decodable { let collection: [Track]; let next_href: String? }
                    let page = try JSONDecoder().decode(Page.self, from: data)
                    return (page.collection, page.next_href)
                }
            )
            AppLogger.shared.log("Likes via /likes/tracks: \(tracks.count) tracks", category: "Network")
            return tracks
        } catch {
            AppLogger.shared.log("Likes /likes/tracks failed (\(error)), trying /likes", category: "Network")
        }
        // /likes returns {kind:"like", track:{...}} objects — extract the track sub-object
        struct LikeItem: Decodable { let track: Track? }
        let tracks = try await paginateLikes(
            startURL: "\(base)/users/\(userID)/likes",
            decode: { data in
                struct Page: Decodable { let collection: [LikeItem]; let next_href: String? }
                let page = try JSONDecoder().decode(Page.self, from: data)
                return (page.collection.compactMap { $0.track }, page.next_href)
            }
        )
        AppLogger.shared.log("Likes via /likes: \(tracks.count) tracks", category: "Network")
        return tracks
    }

    private func paginateLikes(startURL: String,
                                decode: (Data) throws -> ([Track], String?)) async throws -> [Track] {
        var all: [Track] = []
        var nextURLStr: String? = startURL
        while let urlStr = nextURLStr, all.count < 500 {
            var comps = URLComponents(string: urlStr)!
            var items = comps.queryItems ?? []
            func set(_ name: String, _ value: String) {
                if !items.contains(where: { $0.name == name }) { items.append(URLQueryItem(name: name, value: value)) }
            }
            set("client_id", Constants.soundcloudClientID)
            set("limit", "50")
            set("linked_partitioning", "1")
            comps.queryItems = items
            guard let url = comps.url else { break }
            let (data, resp) = try await URLSession.shared.data(from: url)
            try validate(resp)
            let (tracks, next) = try decode(data)
            all.append(contentsOf: tracks)
            nextURLStr = tracks.isEmpty ? nil : next
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
