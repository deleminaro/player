import Foundation
import AuthenticationServices
import CryptoKit
import Security

// MARK: - SpotifyService

@MainActor
final class SpotifyService: NSObject, ObservableObject {
    static let shared = SpotifyService()
    private override init() {
        super.init()
        loadTokens()
    }

    @Published var isAuthenticated = false

    // MARK: - Tokens (Keychain-backed, expiry in UserDefaults)

    private var accessToken:  String?
    private var refreshToken: String?
    private var tokenExpiry:  Date = .distantPast
    private var codeVerifier: String?
    private var authSession:  ASWebAuthenticationSession?

    private let kAccess       = "sp_access_token"
    private let kRefresh      = "sp_refresh_token"
    private let kExpiry       = "sp_token_expiry"
    private let kKeychainSvc  = "com.postor.spotify"
    private let redirectURI   = "postor://spotify-callback"

    // MARK: - In-memory response cache

    private struct CacheEntry { let data: Data; let expires: Date }
    private var cache: [String: CacheEntry] = [:]
    private let searchTTL:  TimeInterval = 300    // 5 min
    private let profileTTL: TimeInterval = 1800   // 30 min

    private func cached(_ key: String) -> Data? {
        guard let e = cache[key], e.expires > Date() else { cache.removeValue(forKey: key); return nil }
        return e.data
    }
    private func store(_ data: Data, key: String, ttl: TimeInterval) {
        cache[key] = CacheEntry(data: data, expires: Date().addingTimeInterval(ttl))
    }

    // MARK: - Centralised authenticated request (429-aware)

    // Injects the Bearer token and retries on HTTP 429 using the Retry-After header.
    private func perform(_ request: URLRequest, attempt: Int = 0) async throws -> Data {
        let token = try await validToken()
        var req = request
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw SpotifyError.apiError("No HTTP response")
        }
        // Rate limit — honour Retry-After, max 3 retries
        if http.statusCode == 429 && attempt < 3 {
            let wait = Double(http.value(forHTTPHeaderField: "Retry-After") ?? "2") ?? 2.0
            try await Task.sleep(nanoseconds: UInt64(min(wait, 30) * 1_000_000_000))
            return try await perform(request, attempt: attempt + 1)
        }
        if http.statusCode == 401 || http.statusCode == 403 { logout(); throw SpotifyError.notAuthenticated }
        try checkStatus(resp, data: data)
        return data
    }

    // MARK: - Search: Tracks

    func search(query: String, offset: Int = 0) async throws -> [Track] {
        let key = "tracks:\(query):\(offset)"
        let data: Data
        if let hit = cached(key) { data = hit } else {
            var comps = URLComponents(string: "\(Constants.Spotify.baseURL)/search")!
            comps.queryItems = [
                .init(name: "q",      value: query),
                .init(name: "type",   value: "track"),
                .init(name: "limit",  value: "20"),
                .init(name: "offset", value: "\(min(offset, 990))"),
                .init(name: "market", value: "AU"),
            ]
            data = try await perform(URLRequest(url: comps.url!))
            store(data, key: key, ttl: searchTTL)
        }
        return try JSONDecoder().decode(SpotifySearchResponse.self, from: data)
            .tracks.items.compactMap { track(from: $0) }
    }

    // MARK: - Search: Artists

    func searchArtists(query: String, offset: Int = 0) async throws -> [SpotifyArtistResult] {
        let key = "artists:\(query):\(offset)"
        let data: Data
        if let hit = cached(key) { data = hit } else {
            var comps = URLComponents(string: "\(Constants.Spotify.baseURL)/search")!
            comps.queryItems = [
                .init(name: "q",      value: query),
                .init(name: "type",   value: "artist"),
                .init(name: "limit",  value: "20"),
                .init(name: "offset", value: "\(min(offset, 990))"),
                .init(name: "market", value: "AU"),
            ]
            data = try await perform(URLRequest(url: comps.url!))
            store(data, key: key, ttl: searchTTL)
        }
        return try JSONDecoder().decode(SpotifySearchArtistResponse.self, from: data)
            .artists.items.map { artistResult(from: $0) }
    }

    // MARK: - Search: Albums

    func searchAlbums(query: String, offset: Int = 0) async throws -> [SpotifyAlbumResult] {
        let key = "albums:\(query):\(offset)"
        let data: Data
        if let hit = cached(key) { data = hit } else {
            var comps = URLComponents(string: "\(Constants.Spotify.baseURL)/search")!
            comps.queryItems = [
                .init(name: "q",      value: query),
                .init(name: "type",   value: "album"),
                .init(name: "limit",  value: "20"),
                .init(name: "offset", value: "\(min(offset, 990))"),
                .init(name: "market", value: "AU"),
            ]
            data = try await perform(URLRequest(url: comps.url!))
            store(data, key: key, ttl: searchTTL)
        }
        return try JSONDecoder().decode(SpotifySearchAlbumResponse.self, from: data)
            .albums.items.map { albumResult(from: $0) }
    }

    // MARK: - Artist: Top Tracks

    func fetchArtistTopTracks(artistID: String) async throws -> [Track] {
        let key = "topTracks:\(artistID)"
        let data: Data
        if let hit = cached(key) {
            data = hit
        } else {
            var comps = URLComponents(string: "\(Constants.Spotify.baseURL)/artists/\(artistID)/top-tracks")!
            comps.queryItems = [.init(name: "market", value: "AU")]
            do {
                data = try await perform(URLRequest(url: comps.url!))
            } catch SpotifyError.notAuthenticated {
                throw SpotifyError.notAuthenticated
            } catch {
                // Endpoint may be restricted in Dev Mode — return empty gracefully
                return []
            }
            store(data, key: key, ttl: profileTTL)
        }
        return try JSONDecoder().decode(SpotifyTopTracksResponse.self, from: data)
            .tracks.compactMap { track(from: $0) }
    }

    // MARK: - Artist: Albums

    func fetchArtistAlbums(artistID: String) async throws -> [SpotifyAlbumResult] {
        let key = "artistAlbums:\(artistID)"
        let data: Data
        if let hit = cached(key) {
            data = hit
        } else {
            var comps = URLComponents(string: "\(Constants.Spotify.baseURL)/artists/\(artistID)/albums")!
            comps.queryItems = [
                .init(name: "limit",          value: "20"),
                .init(name: "include_groups", value: "album,single"),
                .init(name: "market",         value: "AU"),
            ]
            data = try await perform(URLRequest(url: comps.url!))
            store(data, key: key, ttl: profileTTL)
        }
        return try JSONDecoder().decode(SpotifyArtistAlbumsResponse.self, from: data)
            .items.map { albumResult(from: $0) }
    }

    // MARK: - Mapping helpers

    private func artistResult(from dto: SpotifyFullArtistDTO) -> SpotifyArtistResult {
        SpotifyArtistResult(
            id:             dto.id,
            name:           dto.name,
            imageURL:       dto.images?.first(where: { ($0.width ?? 0) >= 300 })?.url ?? dto.images?.first?.url,
            followersCount: dto.followers?.total,
            genres:         dto.genres ?? []
        )
    }

    private func albumResult(from dto: SpotifyAlbumItemDTO) -> SpotifyAlbumResult {
        SpotifyAlbumResult(
            id:          dto.id,
            name:        dto.name,
            imageURL:    dto.images.first(where: { ($0.width ?? 0) >= 300 })?.url ?? dto.images.first?.url,
            releaseYear: String(dto.releaseDate.prefix(4)),
            albumType:   dto.albumType,
            artistName:  dto.artists?.first?.name
        )
    }

    // MARK: - PKCE Auth

    func startAuth() async throws {
        let verifier  = generateCodeVerifier()
        codeVerifier  = verifier
        let challenge = generateCodeChallenge(from: verifier)

        var comps = URLComponents(string: "https://accounts.spotify.com/authorize")!
        comps.queryItems = [
            .init(name: "client_id",            value: Constants.spotifyClientID),
            .init(name: "response_type",         value: "code"),
            .init(name: "redirect_uri",          value: redirectURI),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "code_challenge",        value: challenge),
            .init(name: "scope", value: "streaming user-read-private user-read-email user-read-playback-state user-modify-playback-state user-read-currently-playing")
        ]
        guard let authURL = comps.url else { throw SpotifyError.authFailed }

        let callbackURL: URL = try await withCheckedThrowingContinuation { cont in
            let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: "postor") { url, error in
                if let err = error {
                    let asErr = err as? ASWebAuthenticationSessionError
                    cont.resume(throwing: asErr?.code == .canceledLogin ? SpotifyError.authCancelled : err)
                } else if let url {
                    cont.resume(returning: url)
                } else {
                    cont.resume(throwing: SpotifyError.authFailed)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.authSession = session
            session.start()
        }
        authSession = nil

        guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value
        else { throw SpotifyError.authFailed }

        try await exchangeCode(code)
    }

    private func exchangeCode(_ code: String) async throws {
        guard let verifier = codeVerifier else { throw SpotifyError.authFailed }
        var req = URLRequest(url: URL(string: Constants.Spotify.tokenURL)!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = [
            "grant_type=authorization_code",
            "code=\(code)",
            "redirect_uri=\(redirectURI)",
            "client_id=\(Constants.spotifyClientID)",
            "code_verifier=\(verifier)"
        ].joined(separator: "&").data(using: .utf8)

        let (data, resp) = try await URLSession.shared.data(for: req)
        try checkStatus(resp, data: data)
        applyTokenResponse(try JSONDecoder().decode(PKCETokenResponse.self, from: data))
    }

    func logout() {
        accessToken  = nil
        refreshToken = nil
        tokenExpiry  = .distantPast
        isAuthenticated = false
        keychainDelete(forKey: kAccess)
        keychainDelete(forKey: kRefresh)
        UserDefaults.standard.removeObject(forKey: kExpiry)
        cache.removeAll()
    }

    // MARK: - Token management

    private func validToken() async throws -> String {
        if let tok = accessToken, tokenExpiry > Date() { return tok }
        if refreshToken != nil {
            do { try await refreshAccessToken() } catch {
                logout(); throw SpotifyError.notAuthenticated
            }
            guard let tok = accessToken else { throw SpotifyError.notAuthenticated }
            return tok
        }
        throw SpotifyError.notAuthenticated
    }

    private func refreshAccessToken() async throws {
        guard let refresh = refreshToken else { throw SpotifyError.notAuthenticated }
        var req = URLRequest(url: URL(string: Constants.Spotify.tokenURL)!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = [
            "grant_type=refresh_token",
            "refresh_token=\(refresh)",
            "client_id=\(Constants.spotifyClientID)"
        ].joined(separator: "&").data(using: .utf8)

        let (data, resp) = try await URLSession.shared.data(for: req)
        try checkStatus(resp, data: data)
        applyTokenResponse(try JSONDecoder().decode(PKCETokenResponse.self, from: data))
    }

    private func applyTokenResponse(_ t: PKCETokenResponse) {
        accessToken  = t.accessToken
        if let r = t.refreshToken { refreshToken = r }
        tokenExpiry  = Date().addingTimeInterval(Double(t.expiresIn) - 30)
        isAuthenticated = true
        saveTokens()
    }

    // MARK: - Persistence (Keychain for secrets, UserDefaults for expiry)

    private func saveTokens() {
        if let a = accessToken  { keychainSave(a, forKey: kAccess)  }
        if let r = refreshToken { keychainSave(r, forKey: kRefresh) }
        UserDefaults.standard.set(tokenExpiry, forKey: kExpiry)
    }

    private func loadTokens() {
        accessToken  = keychainLoad(forKey: kAccess)
        refreshToken = keychainLoad(forKey: kRefresh)
        tokenExpiry  = UserDefaults.standard.object(forKey: kExpiry) as? Date ?? .distantPast
        isAuthenticated = refreshToken != nil
    }

    // MARK: - Keychain helpers

    private func keychainSave(_ value: String, forKey account: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      kKeychainSvc,
            kSecAttrAccount:      account,
            kSecValueData:        data,
            kSecAttrAccessible:   kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func keychainLoad(forKey account: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: kKeychainSvc,
            kSecAttrAccount: account,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func keychainDelete(forKey account: String) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: kKeychainSvc,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - PKCE helpers

    private func generateCodeVerifier() -> String {
        var buf = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buf.count, &buf)
        return Data(buf).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - HTTP status check

    private func checkStatus(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse,
              !(200..<300).contains(http.statusCode) else { return }
        let msg = (try? JSONDecoder().decode(SpotifyAPIError.self,   from: data))?.error.message
               ?? (try? JSONDecoder().decode(SpotifyTokenError.self, from: data))?.errorDescription
               ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
        throw SpotifyError.apiError("Spotify \(http.statusCode): \(msg)")
    }

    // MARK: - Track mapping

    private func track(from dto: SpotifyTrackDTO) -> Track? {
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
            previewURL:   dto.previewUrl
        )
    }

    private func stableID(from id: String) -> Int {
        var h: UInt64 = 5381
        for c in id.utf8 { h = (h &<< 5) &+ h &+ UInt64(c) }
        return Int(bitPattern: UInt(h & 0x7FFFFFFFFFFFFFFF))
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension SpotifyService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

// MARK: - Public result types

struct SpotifyArtistResult: Identifiable {
    let id:             String
    let name:           String
    let imageURL:       String?
    let followersCount: Int?
    let genres:         [String]
}

struct SpotifyAlbumResult: Identifiable {
    let id:         String
    let name:       String
    let imageURL:   String?
    let releaseYear: String
    let albumType:  String    // "album", "single"
    var artistName: String?
}

// MARK: - Response DTOs (private)

private struct PKCETokenResponse: Decodable {
    let accessToken:  String
    let refreshToken: String?
    let expiresIn:    Int
    enum CodingKeys: String, CodingKey {
        case accessToken  = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn    = "expires_in"
    }
}

private struct SpotifySearchResponse: Decodable {
    let tracks: SpotifyTrackPage
}

private struct SpotifyTrackPage: Decodable {
    let items: [SpotifyTrackDTO]
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        var arr = try c.nestedUnkeyedContainer(forKey: .items)
        var result: [SpotifyTrackDTO] = []
        while !arr.isAtEnd {
            if let item = try? arr.decode(SpotifyTrackDTO.self) { result.append(item) }
            else { _ = try? arr.decode(AnyDecodable.self) }
        }
        items = result
    }
    enum CodingKeys: String, CodingKey { case items }
}

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

private struct SpotifyArtistDTO:    Decodable { let id: String; let name: String }
private struct SpotifyAlbumDTO:     Decodable { let images: [SpotifyImageDTO] }
private struct SpotifyImageDTO:     Decodable { let url: String; let width: Int?; let height: Int? }
private struct SpotifyExternalURLs: Decodable { let spotify: String }

private struct SpotifySearchArtistResponse: Decodable {
    let artists: SpotifyArtistPage
}

private struct SpotifyArtistPage: Decodable {
    let items: [SpotifyFullArtistDTO]
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        var arr = try c.nestedUnkeyedContainer(forKey: .items)
        var result: [SpotifyFullArtistDTO] = []
        while !arr.isAtEnd {
            if let item = try? arr.decode(SpotifyFullArtistDTO.self) { result.append(item) }
            else { _ = try? arr.decode(AnyDecodable.self) }
        }
        items = result
    }
    enum CodingKeys: String, CodingKey { case items }
}

private struct SpotifyFullArtistDTO: Decodable {
    let id:        String
    let name:      String
    let images:    [SpotifyImageDTO]?
    let followers: SpotifyFollowersDTO?
    let genres:    [String]?
}

private struct SpotifyFollowersDTO: Decodable { let total: Int }

private struct SpotifyTopTracksResponse: Decodable { let tracks: [SpotifyTrackDTO] }

private struct SpotifyArtistAlbumsResponse: Decodable { let items: [SpotifyAlbumItemDTO] }

// Shared DTO for artist albums + album search results
private struct SpotifyAlbumItemDTO: Decodable {
    let id:          String
    let name:        String
    let images:      [SpotifyImageDTO]
    let releaseDate: String
    let albumType:   String
    let artists:     [SpotifyArtistDTO]?
    enum CodingKeys: String, CodingKey {
        case id, name, images, artists
        case releaseDate = "release_date"
        case albumType   = "album_type"
    }
}

private struct SpotifySearchAlbumResponse: Decodable {
    let albums: SpotifyAlbumSearchPage
}

private struct SpotifyAlbumSearchPage: Decodable {
    let items: [SpotifyAlbumItemDTO]
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        var arr = try c.nestedUnkeyedContainer(forKey: .items)
        var result: [SpotifyAlbumItemDTO] = []
        while !arr.isAtEnd {
            if let item = try? arr.decode(SpotifyAlbumItemDTO.self) { result.append(item) }
            else { _ = try? arr.decode(AnyDecodable.self) }
        }
        items = result
    }
    enum CodingKeys: String, CodingKey { case items }
}

private struct SpotifyAPIError: Decodable {
    struct Detail: Decodable { let message: String }
    let error: Detail
}

private struct SpotifyTokenError: Decodable {
    let error:            String
    let errorDescription: String?
    enum CodingKeys: String, CodingKey {
        case error; case errorDescription = "error_description"
    }
}

// MARK: - Error type

enum SpotifyError: LocalizedError {
    case badCredentials, authFailed, authCancelled, notAuthenticated
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .badCredentials:   return "Invalid Spotify credentials"
        case .authFailed:       return "Spotify authentication failed"
        case .authCancelled:    return "Spotify login was cancelled"
        case .notAuthenticated: return "Connect your Spotify account first"
        case .apiError(let m):  return m
        }
    }
}
