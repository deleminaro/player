import Foundation
import AuthenticationServices
import CryptoKit

@MainActor
final class SpotifyService: NSObject, ObservableObject {
    static let shared = SpotifyService()
    private override init() {
        super.init()
        loadTokens()
    }

    @Published var isAuthenticated = false

    private var accessToken:  String?
    private var refreshToken: String?
    private var tokenExpiry:  Date = .distantPast
    private var codeVerifier: String?
    private var authSession:  ASWebAuthenticationSession?

    private let kAccess  = "sp_access_token"
    private let kRefresh = "sp_refresh_token"
    private let kExpiry  = "sp_token_expiry"
    private let redirectURI = "postor://spotify-callback"

    // MARK: - Search

    func search(query: String, offset: Int = 0) async throws -> [Track] {
        let token = try await validToken()
        var comps = URLComponents(string: "\(Constants.Spotify.baseURL)/search")!
        comps.queryItems = [
            .init(name: "q",    value: query),
            .init(name: "type", value: "track")
        ]
        var req = URLRequest(url: comps.url!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        do {
            try checkStatus(resp, data: data)
        } catch {
            // Token rejected — clear it so the connect screen reappears
            if let http = resp as? HTTPURLResponse, http.statusCode == 401 || http.statusCode == 403 {
                logout()
            }
            throw error
        }
        let decoded = try JSONDecoder().decode(SpotifySearchResponse.self, from: data)
        return decoded.tracks.items.compactMap { track(from: $0) }
    }

    // MARK: - PKCE Auth

    func startAuth() async throws {
        let verifier  = generateCodeVerifier()
        codeVerifier  = verifier
        let challenge = generateCodeChallenge(from: verifier)

        var comps = URLComponents(string: "https://accounts.spotify.com/authorize")!
        comps.queryItems = [
            .init(name: "client_id",             value: Constants.spotifyClientID),
            .init(name: "response_type",          value: "code"),
            .init(name: "redirect_uri",           value: redirectURI),
            .init(name: "code_challenge_method",  value: "S256"),
            .init(name: "code_challenge",         value: challenge),
            .init(name: "scope",                  value: "user-read-private")
        ]
        guard let authURL = comps.url else { throw SpotifyError.authFailed }

        let callbackURL: URL = try await withCheckedThrowingContinuation { cont in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "postor"
            ) { url, error in
                if let err = error {
                    let asErr = err as? ASWebAuthenticationSessionError
                    cont.resume(throwing: asErr?.code == .canceledLogin
                        ? SpotifyError.authCancelled : err)
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
        let t = try JSONDecoder().decode(PKCETokenResponse.self, from: data)
        applyTokenResponse(t)
    }

    func logout() {
        accessToken  = nil
        refreshToken = nil
        tokenExpiry  = .distantPast
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: kAccess)
        UserDefaults.standard.removeObject(forKey: kRefresh)
        UserDefaults.standard.removeObject(forKey: kExpiry)
    }

    // MARK: - Token management

    private func validToken() async throws -> String {
        if let tok = accessToken, tokenExpiry > Date() { return tok }
        if refreshToken != nil {
            do {
                try await refreshAccessToken()
            } catch {
                logout()
                throw SpotifyError.notAuthenticated
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
        let t = try JSONDecoder().decode(PKCETokenResponse.self, from: data)
        applyTokenResponse(t)
    }

    private func applyTokenResponse(_ t: PKCETokenResponse) {
        accessToken  = t.accessToken
        if let r = t.refreshToken { refreshToken = r }
        tokenExpiry  = Date().addingTimeInterval(Double(t.expiresIn) - 30)
        isAuthenticated = true
        saveTokens()
    }

    // MARK: - Persistence

    private func saveTokens() {
        let d = UserDefaults.standard
        d.set(accessToken,  forKey: kAccess)
        d.set(refreshToken, forKey: kRefresh)
        d.set(tokenExpiry,  forKey: kExpiry)
    }

    private func loadTokens() {
        let d = UserDefaults.standard
        accessToken  = d.string(forKey: kAccess)
        refreshToken = d.string(forKey: kRefresh)
        tokenExpiry  = d.object(forKey: kExpiry) as? Date ?? .distantPast
        isAuthenticated = refreshToken != nil
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

    // MARK: - HTTP check

    private func checkStatus(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse,
              !(200..<300).contains(http.statusCode) else { return }
        let msg = (try? JSONDecoder().decode(SpotifyAPIError.self, from: data))?.error.message
               ?? (try? JSONDecoder().decode(SpotifyTokenError.self, from: data))?.errorDescription
               ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
        throw SpotifyError.apiError("Spotify \(http.statusCode): \(msg)")
    }

    // MARK: - Track mapping

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

// MARK: - Response types

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

private struct SpotifyArtistDTO: Decodable { let name: String }
private struct SpotifyAlbumDTO:  Decodable { let images: [SpotifyImageDTO] }
private struct SpotifyImageDTO:  Decodable { let url: String; let width: Int?; let height: Int? }
private struct SpotifyExternalURLs: Decodable { let spotify: String }

private struct SpotifyAPIError: Decodable {
    struct Detail: Decodable { let message: String }
    let error: Detail
}

private struct SpotifyTokenError: Decodable {
    let error: String
    let errorDescription: String?
    enum CodingKeys: String, CodingKey {
        case error; case errorDescription = "error_description"
    }
}

enum SpotifyError: LocalizedError {
    case badCredentials, authFailed, authCancelled, notAuthenticated
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .badCredentials:    return "Invalid Spotify credentials"
        case .authFailed:        return "Spotify authentication failed"
        case .authCancelled:     return "Spotify login was cancelled"
        case .notAuthenticated:  return "Connect your Spotify account first"
        case .apiError(let m):   return m
        }
    }
}
