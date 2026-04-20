import Foundation

actor GeniusService {
    static let shared = GeniusService()

    private let base = Constants.Genius.baseURL

    /// Returns the Genius web-page URL for the best-matching song, or nil if nothing found.
    func searchLyricsURL(title: String, artist: String) async throws -> URL? {
        let q = "\(cleanTitle(title)) \(artist.trimmingCharacters(in: .whitespaces))"
        var comps = URLComponents(string: "\(base)/search")!
        comps.queryItems = [URLQueryItem(name: "q", value: q)]
        guard let url = comps.url else { return nil }

        var req = URLRequest(url: url)
        req.setValue("Bearer \(Constants.geniusToken)", forHTTPHeaderField: "Authorization")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            return nil
        }

        let decoded = try JSONDecoder().decode(GeniusSearchResponse.self, from: data)
        guard let firstHit = decoded.response.hits.first else { return nil }
        return URL(string: firstHit.result.url)
    }

    // MARK: - Title cleaning

    private func cleanTitle(_ raw: String) -> String {
        var s = raw
        let patterns = [
            #"\s*[\(\[][^)\]]*(?:prod\.?(?:\s+by)?|feat\.?|ft\.?|w\/)[^\)\]]*[\)\]]"#,
            #"\s*[\(\[](?:prod\.?(?:\s+by)?|feat\.?|ft\.?|w\/)[^\)\]]*[\)\]]"#,
            #"\s*\((?:original mix|remix|radio edit|extended mix)\)"#
        ]
        for p in patterns {
            s = s.replacingOccurrences(of: p, with: "",
                                       options: [.regularExpression, .caseInsensitive])
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private struct GeniusSearchResponse: Decodable {
        let response: Response

        struct Response: Decodable {
            let hits: [Hit]
        }
        struct Hit: Decodable {
            let result: Result
        }
        struct Result: Decodable {
            let url: String
        }
    }
}
