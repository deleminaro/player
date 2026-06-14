import Foundation

// Centralised client for all calls to the POSTOR backend proxy.
// The backend holds Genius tokens and SoundCloud client_id — this app
// never sends them directly to third-party APIs.

final class BackendClient {
    static let shared = BackendClient()
    private init() {}

    private let baseURL = Constants.Backend.baseURL
    private let session = URLSession(configuration: .ephemeral)  // no on-disk cache

    // MARK: - Request builder

    private func request(_ path: String, queryItems: [URLQueryItem] = []) throws -> URLRequest {
        guard var comps = URLComponents(string: baseURL + path) else {
            throw BackendError.badURL
        }
        if !queryItems.isEmpty { comps.queryItems = queryItems }
        guard let url = comps.url else { throw BackendError.badURL }

        var req = URLRequest(url: url, timeoutInterval: 12)
        // App-level authentication — loaded from xcconfig, never hardcoded
        req.setValue(Constants.backendAPIKey, forHTTPHeaderField: "X-App-Key")
        req.setValue("application/json",      forHTTPHeaderField: "Accept")
        return req
    }

    // MARK: - Execute

    private func perform<T: Decodable>(_ req: URLRequest) async throws -> T {
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw BackendError.noResponse }

        switch http.statusCode {
        case 200..<300: break
        case 401:       throw BackendError.unauthorized
        case 429:       throw BackendError.rateLimited
        default:
            let msg = (try? JSONDecoder().decode(BackendErrorBody.self, from: data))?.error
                   ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw BackendError.apiError(http.statusCode, msg)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Genius

    /// Returns candidate lyrics page URLs for (title, artist).
    func geniusSearch(query: String) async throws -> [GeniusHit] {
        let req = try request("/api/genius/search", queryItems: [
            .init(name: "q", value: query)
        ])
        let resp: GeniusSearchResponse = try await perform(req)
        return resp.hits
    }

    // MARK: - SoundCloud

    func soundcloudSearch(query: String, offset: Int = 0, limit: Int = 20) async throws -> Data {
        let req = try request("/api/soundcloud/search", queryItems: [
            .init(name: "q",      value: query),
            .init(name: "offset", value: "\(offset)"),
            .init(name: "limit",  value: "\(limit)"),
        ])
        let (data, resp) = try await session.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw BackendError.apiError(0, "SoundCloud search failed")
        }
        return data
    }

    /// Resolves a SoundCloud transcoding URL to a playable CDN stream URL.
    func soundcloudStreamURL(transcodingURL: String) async throws -> URL {
        let req = try request("/api/soundcloud/stream", queryItems: [
            .init(name: "url", value: transcodingURL)
        ])
        let resp: StreamURLResponse = try await perform(req)
        guard let url = URL(string: resp.url) else { throw BackendError.badURL }
        return url
    }
}

// MARK: - Response types

struct GeniusSearchResponse: Decodable {
    let hits: [GeniusHit]
}

struct GeniusHit: Decodable {
    let title:   String
    let artist:  String
    let url:     String    // Genius lyrics page
    let artwork: String?
}

private struct StreamURLResponse: Decodable { let url: String }
private struct BackendErrorBody:  Decodable { let error: String }

// MARK: - Errors

enum BackendError: LocalizedError {
    case badURL, noResponse, unauthorized, rateLimited
    case apiError(Int, String)

    var errorDescription: String? {
        switch self {
        case .badURL:              return "Invalid URL"
        case .noResponse:          return "No response from server"
        case .unauthorized:        return "App key rejected — check configuration"
        case .rateLimited:         return "Too many requests, please wait"
        case .apiError(let s, let m): return "Server error \(s): \(m)"
        }
    }
}
