import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import AuthenticationServices
import CryptoKit
import GoogleSignIn
import UIKit
import SwiftUI

// MARK: - User model

struct AppUser {
    let uid: String
    var username: String
    var displayName: String
    var email: String
    var avatarBase64: String?

    var avatarImage: UIImage? {
        guard let b64 = avatarBase64,
              let data = Data(base64Encoded: b64) else { return nil }
        return UIImage(data: data)
    }
}

// MARK: - Firebase manager

@MainActor
final class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()

    @Published var isLoggedIn  = false
    @Published var currentUser: AppUser?
    @Published var isLoading   = false

    private let auth = Auth.auth()
    private let db   = Firestore.firestore()

    init() {
        auth.addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                self?.isLoggedIn = user != nil
                if let uid = user?.uid {
                    await self?.loadProfile(uid: uid)
                } else {
                    self?.currentUser = nil
                }
            }
        }
    }

    // MARK: - Email / Password sign up

    func signUp(username: String, email: String, password: String) async throws {
        let uname = username.trimmingCharacters(in: .whitespaces).lowercased()
        guard !uname.isEmpty else { throw PError.invalidUsername }

        let taken = try await db.collection("usernames").document(uname).getDocument()
        if taken.exists { throw PError.usernameTaken }

        let result = try await auth.createUser(withEmail: email, password: password)
        let uid = result.user.uid

        let profile: [String: Any] = [
            "username":    uname,
            "displayName": username.trimmingCharacters(in: .whitespaces),
            "email":       email
        ]
        try await db.collection("users").document(uid)
            .collection("profile").document("info").setData(profile)
        try await db.collection("usernames").document(uname)
            .setData(["uid": uid, "email": email])

        currentUser = AppUser(uid: uid,
                              username: uname,
                              displayName: username.trimmingCharacters(in: .whitespaces),
                              email: email)
    }

    // MARK: - Email / Password login

    func login(usernameOrEmail: String, password: String) async throws {
        let query = usernameOrEmail.trimmingCharacters(in: .whitespaces)
        let email: String
        if query.contains("@") {
            email = query
        } else {
            let doc = try await db.collection("usernames").document(query.lowercased()).getDocument()
            guard let e = doc.data()?["email"] as? String else { throw PError.userNotFound }
            email = e
        }
        try await auth.signIn(withEmail: email, password: password)
    }

    // MARK: - Sign in with Apple

    func signInWithApple(credential: ASAuthorizationAppleIDCredential, nonce: String) async throws {
        guard let appleIDToken = credential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw PError.invalidCredential
        }
        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: credential.fullName
        )
        let result = try await auth.signIn(with: firebaseCredential)
        let uid = result.user.uid
        let docRef = db.collection("users").document(uid).collection("profile").document("info")
        if (try? await docRef.getDocument())?.exists != true {
            let givenName  = credential.fullName?.givenName  ?? ""
            let familyName = credential.fullName?.familyName ?? ""
            let display    = [givenName, familyName].filter { !$0.isEmpty }.joined(separator: " ")
            let profile: [String: Any] = [
                "username":    uid,
                "displayName": display.isEmpty ? "Apple User" : display,
                "email":       result.user.email ?? credential.email ?? ""
            ]
            try await docRef.setData(profile)
        }
    }

    // MARK: - Sign in with Google

    func signInWithGoogle() async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        guard let vc = windowScene?.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            throw PError.noViewController
        }

        let result     = try await GIDSignIn.sharedInstance.signIn(withPresenting: vc)
        guard let idToken = result.user.idToken?.tokenString else { throw PError.invalidCredential }
        let accessToken = result.user.accessToken.tokenString
        let gCredential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        let authResult  = try await auth.signIn(with: gCredential)

        let uid = authResult.user.uid
        let docRef = db.collection("users").document(uid).collection("profile").document("info")
        if (try? await docRef.getDocument())?.exists != true {
            let profile: [String: Any] = [
                "username":    uid,
                "displayName": result.user.profile?.name ?? "Google User",
                "email":       result.user.profile?.email ?? authResult.user.email ?? ""
            ]
            try await docRef.setData(profile)
        }
    }

    // MARK: - Log out

    func logOut() {
        try? auth.signOut()
        GIDSignIn.sharedInstance.signOut()
        currentUser = nil
        isLoggedIn  = false
    }

    // MARK: - Profile update

    func updateDisplayName(_ name: String) async throws {
        guard let uid = auth.currentUser?.uid else { return }
        try await db.collection("users").document(uid)
            .collection("profile").document("info")
            .updateData(["displayName": name])
        currentUser?.displayName = name
    }

    func updateAvatar(_ image: UIImage) async throws {
        guard let uid = auth.currentUser?.uid else { return }
        let resized = image.resized(to: CGSize(width: 200, height: 200))
        guard let data = resized.jpegData(compressionQuality: 0.5) else { return }
        let b64 = data.base64EncodedString()
        try await db.collection("users").document(uid)
            .collection("profile").document("info")
            .updateData(["avatarBase64": b64])
        currentUser?.avatarBase64 = b64
    }

    // MARK: - Sync data

    func syncLikedTracks(_ tracks: [Track]) async {
        guard let uid = auth.currentUser?.uid,
              let data = try? JSONEncoder().encode(tracks),
              let str  = String(data: data, encoding: .utf8) else { return }
        try? await db.collection("users").document(uid)
            .collection("data").document("liked")
            .setData(["tracks": str])
    }

    func syncPlaylists(_ playlists: [LocalPlaylist]) async {
        guard let uid = auth.currentUser?.uid,
              let data = try? JSONEncoder().encode(playlists),
              let str  = String(data: data, encoding: .utf8) else { return }
        try? await db.collection("users").document(uid)
            .collection("data").document("playlists")
            .setData(["playlists": str])
    }

    func loadUserData() async -> (liked: [Track], playlists: [LocalPlaylist]) {
        guard let uid = auth.currentUser?.uid else { return ([], []) }
        async let likedFetch     = db.collection("users").document(uid)
            .collection("data").document("liked").getDocument()
        async let playlistsFetch = db.collection("users").document(uid)
            .collection("data").document("playlists").getDocument()

        var liked:     [Track]         = []
        var playlists: [LocalPlaylist] = []

        if let str  = (try? await likedFetch)?.data()?["tracks"] as? String,
           let data = str.data(using: .utf8),
           let arr  = try? JSONDecoder().decode([Track].self, from: data) {
            liked = arr
        }
        if let str  = (try? await playlistsFetch)?.data()?["playlists"] as? String,
           let data = str.data(using: .utf8),
           let arr  = try? JSONDecoder().decode([LocalPlaylist].self, from: data) {
            playlists = arr
        }
        return (liked, playlists)
    }

    // MARK: - Apple nonce helpers

    static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Private

    private func loadProfile(uid: String) async {
        guard let data = try? await db.collection("users").document(uid)
            .collection("profile").document("info").getDocument().data() else { return }
        currentUser = AppUser(
            uid:          uid,
            username:     data["username"]     as? String ?? "",
            displayName:  data["displayName"]  as? String ?? "",
            email:        data["email"]        as? String ?? "",
            avatarBase64: data["avatarBase64"] as? String
        )
    }

    // MARK: - Errors

    enum PError: LocalizedError {
        case usernameTaken, userNotFound, invalidUsername, invalidCredential, noViewController
        var errorDescription: String? {
            switch self {
            case .usernameTaken:     return "Username is already taken."
            case .userNotFound:      return "No account found with that username."
            case .invalidUsername:   return "Please enter a valid username."
            case .invalidCredential: return "Unable to complete sign in. Please try again."
            case .noViewController:  return "Unable to present sign in screen."
            }
        }
    }
}

// MARK: - UIImage resize helper

private extension UIImage {
    func resized(to size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
