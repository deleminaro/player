import Foundation

final class SpotifyService {
    static let shared = SpotifyService()
    private init() {}

    private var accessToken: String?
    private var tokenExpiry: Date = .distantPast
    private let session = URLSession.shared

    // MARK: - Search

    func search(query: String, offset: Int = 0) async throws -> [Track] {
        let token = try await validToken()
        var comps = URLComponents(string: "\(Constants.Spotify.baseURL)/search")!
        comps.queryItems = [
            .init(name: "q",      value: query),
            .init(name: "type",   value: "track"),
            .init(name: "limit",  value: "\(Constants.Spotify.searchLimit)"),
            .init(name: "offset", value: "\(offset)")
        ]
        var req = URLRequest(url: comps.url!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await session.data(for: req)
        try checkStatus(resp, data: data)
        let decoded = try JSONDecoder().decode(SpotifySearchResponse.self, from: data)
        return decoded.tracks.items.compactMap { track(from: $0) }
    }

    // MARK: - Token

    private func validToken() async throws -> String {
        if let tok = accessToken, tokenExpiry > Date() { return tok }
        return try await fetchToken()
    }

    private func fetchToken() async throws -> String {
        let creds = "\(Constants.spotifyClientID):\(Constants.spotifyClientSecret)"
        guard let credsData = creds.data(using: .utf8) else { throw SpotifyError.badCredentials }
        let b64 = credsData.base64EncodedString()

        var req = URLRequest(url: URL(string: Constants.Spotify.tokenURL)!)
        req.httpMethod = "POST"
        req.setValue("Basic \(b64)", forHTTPHeaderField: "Authorization")
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = "grant_type=client_credentials".data(using: .utf8)

        let (data, resp) = try await session.data(for: req)
        try checkStatus(resp, data: data)
        let tokenResp = try JSONDecoder().decode(TokenResponse.self, from: data)
        accessToken = tokenResp.accessToken
        tokenExpiry = Date().addingTimeInterval(Double(tokenResp.expiresIn) - 30)
        return tokenResp.accessToken
    }

    // MARK: - HTTP status check

    private func checkStatus(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            let msg = (try? JSONDecoder().decode(SpotifyAPIError.self, from: data))?.error.message
                   ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw SpotifyError.apiError("Spotify \(http.statusCode): \(msg)")
        }
    }

    // MARK: - Mapping

    private func track(from dto: SpotifyTrackDTO) -> Track? {
        guard let previewURL = dto.previewUrl else { return nil }
        let artwork = dto.album?.images.first(where: { $0.width ?? 0 >= 300 })?.url
                   ?? dto.album?.images.first?.url
        return Track(
            id:           stableID(from: dto.id),
            title:        dto.name,
            username:     dto.artists.first?.name ?? "Unknown",
            artworkURL:   artwork,
            duration:     dto.durationMs,
            permalinkURL: dto.externalUrls?.spotify ?? "https://open.spotify.com",
            media:        nil,
            source:       .spotify,
            previewURL:   previewURL
        )
    }

    private func stableID(from spotifyID: String) -> Int {
        var h: UInt64 = 5381
        for c in spotifyID.utf8 { h = (h &<< 5) &+ h &+ UInt64(c) }
        return Int(bitPattern: UInt(h & 0x7FFFFFFFFFFFFFFF))
    }
}

// MARK: - Response types

private struct TokenResponse: Decodable {
    let accessToken: String
    let expiresIn:   Int
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn   = "expires_in"
    }
}

private struct SpotifySearchResponse: Decodable {
    let tracks: SpotifyTrackPage
}

private struct SpotifyTrackPage: Decodable {
    // Use a safe wrapper so one bad item doesn't break the whole list
    let items: [SpotifyTrackDTO]
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var arr = try container.nestedUnkeyedContainer(forKey: .items)
        var result: [SpotifyTrackDTO] = []
        while !arr.isAtEnd {
            if let item = try? arr.decode(SpotifyTrackDTO.self) {
                result.append(item)
            } else {
                _ = try? arr.decode(AnyDecodable.self)
            }
        }
        items = result
    }
    enum CodingKeys: String, CodingKey { case items }
}

// Sink for skipping undecodable items
private struct AnyDecodable: Decodable {}

private struct SpotifyTrackDTO: Decodable {
    let id:           String
    let name:         String
    let durationMs:   Int
    let previewUrl:   String?
    let artists:      [SpotifyArtistDTO]
    let album:        SpotifyAlbumDTO?
    let externalUrls: SpotifyExternalURLs?

    enum CodingKeys: String, CodingKey {
        case id, name, artists, album
        case durationMs   = "duration_ms"
        case previewUrl   = "preview_url"
        case externalUrls = "external_urls"
    }
}

private struct SpotifyArtistDTO: Decodable {
    let name: String
}

private struct SpotifyAlbumDTO: Decodable {
    let images: [SpotifyImageDTO]
}

private struct SpotifyImageDTO: Decodable {
    let url:    String
    let width:  Int?
    let height: Int?
}

private struct SpotifyExternalURLs: Decodable {
    let spotify: String
}

private struct SpotifyAPIError: Decodable {
    struct Detail: Decodable { let message: String }
    let error: Detail
}

enum SpotifyError: LocalizedError {
    case badCredentials
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .badCredentials:   return "Invalid Spotify credentials"
        case .apiError(let m):  return m
        }
    }
}
