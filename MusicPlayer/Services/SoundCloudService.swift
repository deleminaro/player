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

        AppLogger.shared.log("Resolving SC user: \(slug)", category: "Network")

        // Strategy 1: v1 API resolve (different access policy from v2)
        do {
            let user = try await resolveUserV1(slug: slug)
            AppLogger.shared.log("Resolved via v1: id=\(user.id)", category: "Network")
            return user
        } catch {
            AppLogger.shared.log("v1 resolve failed: \(error)", category: "Network")
        }

        // Strategy 2: search with full slug (e.g. "delami-257483686") — finds low-follower accounts
        AppLogger.shared.log("Searching full slug: '\(slug)'", category: "Network")
        do {
            let results = try await searchUsers(query: slug, limit: 10)
            AppLogger.shared.log("Full-slug search: \(results.count) results", category: "Network")
            if let exact = results.first(where: { $0.permalink?.lowercased() == slug }) { return exact }
        } catch {
            AppLogger.shared.log("Full-slug search failed: \(error)", category: "Network")
        }

        // Strategy 3: search by name part with larger limit
        let searchName = slug.range(of: #"-\d+$"#, options: .regularExpression)
            .map { String(slug[..<$0.lowerBound]) } ?? slug
        AppLogger.shared.log("Searching by name: '\(searchName)' limit=200", category: "Network")
        do {
            let results = try await searchUsers(query: searchName, limit: 200)
            AppLogger.shared.log("Name search: \(results.count) results", category: "Network")
            if let exact = results.first(where: { $0.permalink?.lowercased() == slug }) { return exact }
        } catch {
            AppLogger.shared.log("Name search failed: \(error)", category: "Network")
        }

        // Strategy 4: scrape the profile webpage for the embedded user ID
        AppLogger.shared.log("Trying webpage scrape for: '\(slug)'", category: "Network")
        do {
            let user = try await resolveUserFromPage(slug: slug)
            AppLogger.shared.log("Resolved via page scrape: id=\(user.id)", category: "Network")
            return user
        } catch {
            AppLogger.shared.log("Page scrape failed: \(error)", category: "Network")
        }

        AppLogger.shared.log("Could not resolve user: \(slug)", category: "Network")
        throw SCError.badResponse(404)
    }

    private func searchUsers(query: String, limit: Int) async throws -> [SCArtist] {
        var comps = URLComponents(string: "\(base)/search/users")!
        comps.queryItems = [
            URLQueryItem(name: "q",         value: query),
            URLQueryItem(name: "client_id", value: Constants.soundcloudClientID),
            URLQueryItem(name: "limit",     value: "\(limit)"),
        ]
        guard let url = comps.url else { throw SCError.invalidURL }
        let (data, resp) = try await URLSession.shared.data(from: url)
        try validate(resp)
        return try JSONDecoder().decode(SearchResponse<SCArtist>.self, from: data).collection
    }

    private func resolveUserFromPage(slug: String) async throws -> SCArtist {
        guard let pageURL = URL(string: "https://soundcloud.com/\(slug)") else { throw SCError.invalidURL }
        var request = URLRequest(url: pageURL)
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let html = String(data: data, encoding: .utf8) else { throw SCError.invalidURL }
        AppLogger.shared.log("Page fetched, length=\(html.count)", category: "Network")

        // SoundCloud embeds "soundcloud:users:XXXXXXX" in the page hydration JSON
        guard let urnRange = html.range(of: #"soundcloud:users:(\d+)"#, options: .regularExpression) else {
            AppLogger.shared.log("No user urn found in page HTML", category: "Network")
            throw SCError.badResponse(nil)
        }
        let urnFragment = String(html[urnRange])
        guard let idStr = urnFragment.components(separatedBy: ":").last, let userID = Int(idStr) else {
            throw SCError.badResponse(nil)
        }
        AppLogger.shared.log("Extracted user ID from page: \(userID)", category: "Network")

        // Try fetching the full user object from the API; fall back to a stub if blocked
        var comps = URLComponents(string: "\(base)/users/\(userID)")!
        comps.queryItems = [URLQueryItem(name: "client_id", value: Constants.soundcloudClientID)]
        if let apiURL = comps.url,
           let (userData, userResp) = try? await URLSession.shared.data(from: apiURL),
           (userResp as? HTTPURLResponse)?.statusCode == 200,
           let artist = try? JSONDecoder().decode(SCArtist.self, from: userData) {
            return artist
        }
        // API blocked — return stub; fetchUserLikes only needs the id
        return SCArtist(id: userID, username: slug, avatarURL: nil, followersCount: nil, permalink: slug)
    }

    private func resolveUserV1(slug: String) async throws -> SCArtist {
        // SoundCloud v1 API has a different allowlist from v2
        var comps = URLComponents(string: "https://api.soundcloud.com/resolve")!
        comps.queryItems = [
            URLQueryItem(name: "url",       value: "https://soundcloud.com/\(slug)"),
            URLQueryItem(name: "client_id", value: Constants.soundcloudClientID),
        ]
        guard let url = comps.url else { throw SCError.invalidURL }
        let (data, resp) = try await URLSession.shared.data(from: url)
        try validate(resp)
        return try JSONDecoder().decode(SCArtist.self, from: data)
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
