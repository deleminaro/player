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
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SCError.badResponse
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
        case badResponse

        var errorDescription: String? {
            switch self {
            case .invalidURL:   return "Invalid SoundCloud URL."
            case .badResponse:  return "SoundCloud returned an unexpected response. Check your client_id."
            }
        }
    }
}
