import Foundation

actor SoundCloudService {
    static let shared = SoundCloudService()

    private let base = Constants.SoundCloud.baseURL

    // MARK: - Search

    func search(query: String, offset: Int = 0) async throws -> [Track] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }

        var comps = URLComponents(string: "\(base)/search/tracks")!
        comps.queryItems = [
            URLQueryItem(name: "q",         value: query),
            URLQueryItem(name: "client_id", value: Constants.soundcloudClientID),
            URLQueryItem(name: "limit",     value: "\(Constants.SoundCloud.searchLimit)"),
            URLQueryItem(name: "offset",    value: "\(offset)"),
        ]
        guard let url = comps.url else { throw SCError.invalidURL }

        let (data, resp) = try await URLSession.shared.data(from: url)
        try validate(resp)

        let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
        return decoded.collection
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

    private struct SearchResponse: Decodable {
        let collection: [Track]
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
