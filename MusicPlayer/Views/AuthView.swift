import SwiftUI
import AuthenticationServices

// MARK: - Welcome screen

struct WelcomeView: View {
    @EnvironmentObject var firebaseManager: FirebaseManager

    @State private var showLogin  = false
    @State private var showSignUp = false
    @State private var errorMsg   = ""
    @State private var nonce      = FirebaseManager.randomNonceString()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            RadialGradient(
                colors: [Color.white.opacity(0.06), Color.clear],
                center: .top, startRadius: 0, endRadius: 420
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 120, height: 120)
                    Image(systemName: "music.note")
                        .font(.system(size: 48, weight: .ultraLight))
                        .foregroundStyle(.white)
                }
                .padding(.bottom, 28)

                Text("POSTOR")
                    .font(.system(size: 42, weight: .black))
                    .foregroundStyle(.white)
                    .kerning(4)

                Text("Your music, everywhere.")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.top, 10)

                Spacer()

                VStack(spacing: 12) {

                    // Email sign up
                    Button { showSignUp = true } label: {
                        Text("Create Account")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(.white, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(ScaleButtonStyle(scale: 0.96))

                    // Email login
                    Button { showLogin = true } label: {
                        Text("Log In")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    }
                    .buttonStyle(ScaleButtonStyle(scale: 0.96))

                    // Divider
                    HStack {
                        Rectangle().fill(Color.white.opacity(0.15)).frame(height: 1)
                        Text("or")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.35))
                            .padding(.horizontal, 10)
                        Rectangle().fill(Color.white.opacity(0.15)).frame(height: 1)
                    }
                    .padding(.vertical, 2)

                    // Sign in with Apple
                    SignInWithAppleButton(.signIn) { request in
                        nonce = FirebaseManager.randomNonceString()
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = FirebaseManager.sha256(nonce)
                    } onCompletion: { result in
                        switch result {
                        case .success(let auth):
                            guard let cred = auth.credential as? ASAuthorizationAppleIDCredential else { return }
                            let capturedNonce = nonce
                            Task {
                                do {
                                    try await firebaseManager.signInWithApple(credential: cred, nonce: capturedNonce)
                                } catch {
                                    errorMsg = error.localizedDescription
                                }
                            }
                        case .failure(let err):
                            let code = (err as NSError).code
                            if code != ASAuthorizationError.canceled.rawValue {
                                errorMsg = err.localizedDescription
                            }
                        }
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 54)
                    .cornerRadius(16)

                    // Sign in with Google
                    Button {
                        Task {
                            do {
                                try await firebaseManager.signInWithGoogle()
                            } catch {
                                errorMsg = error.localizedDescription
                            }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            GoogleBadge()
                            Text("Continue with Google")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(ScaleButtonStyle(scale: 0.96))

                    if !errorMsg.isEmpty {
                        Text(errorMsg)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.red.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 52)
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $showSignUp) {
            SignUpView().environmentObject(firebaseManager)
        }
        .fullScreenCover(isPresented: $showLogin) {
            LoginView().environmentObject(firebaseManager)
        }
    }
}

// MARK: - Google badge (coloured G circle)

private struct GoogleBadge: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.98, green: 0.26, blue: 0.21),
                            Color(red: 0.13, green: 0.59, blue: 0.95)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 24, height: 24)
            Text("G")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Sign up

struct SignUpView: View {
    @EnvironmentObject var firebaseManager: FirebaseManager
    @Environment(\.dismiss) var dismiss

    @State private var username         = ""
    @State private var email            = ""
    @State private var password         = ""
    @State private var confirmPassword  = ""
    @State private var errorMessage     = ""
    @State private var showPassword     = false
    @State private var isLoading        = false

    @FocusState private var focused: Field?
    private enum Field { case username, email, password, confirm }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button { dismiss() } label: {
                        ZStack {
                            Circle().fill(Color.white.opacity(0.1)).frame(width: 40, height: 40)
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(ScaleButtonStyle(scale: 0.88))
                    Spacer()
                }
                .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 36)

                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Create Account")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Join POSTOR and start listening.")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28).padding(.bottom, 36)

                // Fields
                VStack(spacing: 14) {
                    authField("Username", text: $username, icon: "at",
                              field: .username, focused: $focused)

                    authField("Email", text: $email, icon: "envelope",
                              field: .email, focused: $focused, keyboard: .emailAddress)

                    authFieldSecure("Password", text: $password, icon: "lock",
                                    show: $showPassword, field: .password, focused: $focused)

                    authFieldSecure("Confirm Password", text: $confirmPassword, icon: "lock.fill",
                                    show: $showPassword, field: .confirm, focused: $focused)
                }
                .padding(.horizontal, 28)

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.red.opacity(0.8))
                        .padding(.top, 16)
                        .padding(.horizontal, 28)
                }

                Spacer()

                Button(action: attemptSignUp) {
                    if isLoading {
                        ProgressView().tint(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(.white, in: RoundedRectangle(cornerRadius: 16))
                    } else {
                        Text("Create Account")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(.white, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                .buttonStyle(ScaleButtonStyle(scale: 0.96))
                .disabled(isLoading)
                .padding(.horizontal, 28)
                .padding(.bottom, 48)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func attemptSignUp() {
        guard password == confirmPassword  else { errorMessage = "Passwords don't match."; return }
        guard password.count >= 6          else { errorMessage = "Password must be at least 6 characters."; return }
        guard !username.trimmingCharacters(in: .whitespaces).isEmpty else { errorMessage = "Please enter a username."; return }
        guard email.contains("@")          else { errorMessage = "Please enter a valid email."; return }

        isLoading = true
        errorMessage = ""
        Task {
            do {
                try await firebaseManager.signUp(username: username, email: email, password: password)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Log in

struct LoginView: View {
    @EnvironmentObject var firebaseManager: FirebaseManager
    @Environment(\.dismiss) var dismiss

    @State private var nameOrEmail  = ""
    @State private var password     = ""
    @State private var errorMessage = ""
    @State private var showPassword = false
    @State private var isLoading    = false

    @FocusState private var focused: Field?
    private enum Field { case nameOrEmail, password }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        ZStack {
                            Circle().fill(Color.white.opacity(0.1)).frame(width: 40, height: 40)
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(ScaleButtonStyle(scale: 0.88))
                    Spacer()
                }
                .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 36)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome back")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Log in to continue listening.")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28).padding(.bottom, 36)

                VStack(spacing: 14) {
                    authField("Username or Email", text: $nameOrEmail, icon: "person",
                              field: .nameOrEmail, focused: $focused, keyboard: .emailAddress)

                    authFieldSecure("Password", text: $password, icon: "lock",
                                    show: $showPassword, field: .password, focused: $focused)
                }
                .padding(.horizontal, 28)

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.red.opacity(0.8))
                        .padding(.top, 16)
                        .padding(.horizontal, 28)
                }

                Spacer()

                Button(action: attemptLogin) {
                    if isLoading {
                        ProgressView().tint(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(.white, in: RoundedRectangle(cornerRadius: 16))
                    } else {
                        Text("Log In")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(.white, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                .buttonStyle(ScaleButtonStyle(scale: 0.96))
                .disabled(isLoading)
                .padding(.horizontal, 28)
                .padding(.bottom, 48)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func attemptLogin() {
        isLoading = true
        errorMessage = ""
        Task {
            do {
                try await firebaseManager.login(usernameOrEmail: nameOrEmail, password: password)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Shared field helpers

private func authField<F: Hashable>(
    _ placeholder: String,
    text: Binding<String>,
    icon: String,
    field: F,
    focused: FocusState<F?>.Binding,
    keyboard: UIKeyboardType = .default
) -> some View {
    HStack(spacing: 12) {
        Image(systemName: icon)
            .font(.system(size: 15))
            .foregroundStyle(.white.opacity(0.35))
            .frame(width: 20)
        TextField(placeholder, text: text)
            .foregroundStyle(.white)
            .tint(.white)
            .keyboardType(keyboard)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .focused(focused, equals: field)
    }
    .padding(.horizontal, 18).padding(.vertical, 16)
    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
}

private func authFieldSecure<F: Hashable>(
    _ placeholder: String,
    text: Binding<String>,
    icon: String,
    show: Binding<Bool>,
    field: F,
    focused: FocusState<F?>.Binding
) -> some View {
    HStack(spacing: 12) {
        Image(systemName: icon)
            .font(.system(size: 15))
            .foregroundStyle(.white.opacity(0.35))
            .frame(width: 20)
        Group {
            if show.wrappedValue {
                TextField(placeholder, text: text)
            } else {
                SecureField(placeholder, text: text)
            }
        }
        .foregroundStyle(.white)
        .tint(.white)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .focused(focused, equals: field)

        Button { show.wrappedValue.toggle() } label: {
            Image(systemName: show.wrappedValue ? "eye.slash" : "eye")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.35))
        }
        .buttonStyle(.plain)
    }
    .padding(.horizontal, 18).padding(.vertical, 16)
    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
}
