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

    func fetchLyricsText(from url: URL) async -> String? {
        var req = URLRequest(url: url)
        req.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let html = String(data: data, encoding: .utf8) else { return nil }
        return parseLyricsHTML(html)
    }

    private func parseLyricsHTML(_ html: String) -> String? {
        var blocks: [String] = []
        var search = html[...]
        let marker = #"data-lyrics-container="true""#
        while let r = search.range(of: marker) {
            search = search[r.upperBound...]
            guard let tagEnd = search.range(of: ">") else { break }
            search = search[tagEnd.upperBound...]
            var block = ""
            var depth = 1
            var i = search.startIndex
            while i < search.endIndex && depth > 0 {
                if search[i] == "<" {
                    let rest = search[i...]
                    if rest.hasPrefix("</") {
                        depth -= 1
                        if depth == 0 { break }
                        if let e = rest.range(of: ">") { i = rest[e.upperBound...].startIndex; continue }
                    } else {
                        depth += 1
                        if let tagRange = rest.range(of: ">") {
                            let tag = String(rest[rest.startIndex ..< tagRange.upperBound]).lowercased()
                            if tag.contains("<br") { block += "\n" }
                            i = rest[tagRange.upperBound...].startIndex
                            continue
                        }
                    }
                    break
                } else {
                    block.append(search[i])
                }
                i = search.index(after: i)
            }
            let cleaned = stripTags(block)
            if !cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                blocks.append(cleaned)
            }
        }
        guard !blocks.isEmpty else { return nil }
        return blocks.joined(separator: "\n\n")
    }

    private func stripTags(_ s: String) -> String {
        var out = ""
        var inTag = false
        for ch in s {
            if ch == "<" { inTag = true }
            else if ch == ">" { inTag = false }
            else if !inTag { out.append(ch) }
        }
        return decodeEntities(out)
    }

    private func decodeEntities(_ s: String) -> String {
        s
            .replacingOccurrences(of: "&amp;",  with: "&")
            .replacingOccurrences(of: "&lt;",   with: "<")
            .replacingOccurrences(of: "&gt;",   with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;",  with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
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
