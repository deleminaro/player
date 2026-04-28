import SwiftUI

// MARK: - Auth manager

final class AuthManager: ObservableObject {
    @AppStorage("mp_is_logged_in") var isLoggedIn: Bool = false
    @AppStorage("mp_user_name")    var userName:   String = ""
    @AppStorage("mp_user_email")   var userEmail:  String = ""
    private let kPassword = "mp_user_password"

    func signUp(name: String, email: String, password: String) -> Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty,
              password.count >= 4 else { return false }
        userName  = name.trimmingCharacters(in: .whitespaces)
        userEmail = email.trimmingCharacters(in: .whitespaces)
        UserDefaults.standard.set(password, forKey: kPassword)
        isLoggedIn = true
        return true
    }

    func login(nameOrEmail: String, password: String) -> Bool {
        let storedPW   = UserDefaults.standard.string(forKey: kPassword) ?? ""
        let query      = nameOrEmail.trimmingCharacters(in: .whitespaces).lowercased()
        let matchName  = userName.lowercased() == query
        let matchEmail = userEmail.lowercased() == query
        guard (matchName || matchEmail) && password == storedPW else { return false }
        isLoggedIn = true
        return true
    }

    func logOut() { isLoggedIn = false }
}

// MARK: - Welcome screen

struct WelcomeView: View {
    @State private var showLogin  = false
    @State private var showSignUp = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Subtle radial glow
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
                    Button { showSignUp = true } label: {
                        Text("Create Account")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(.white, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(ScaleButtonStyle(scale: 0.96))

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
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 52)
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $showSignUp) { SignUpView() }
        .fullScreenCover(isPresented: $showLogin)  { LoginView()  }
    }
}

// MARK: - Sign up

struct SignUpView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss

    @State private var name            = ""
    @State private var email           = ""
    @State private var password        = ""
    @State private var confirmPassword = ""
    @State private var errorMessage    = ""
    @State private var showPassword    = false

    @FocusState private var focused: Field?
    private enum Field { case name, email, password, confirm }

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
                    authField("Display Name", text: $name, icon: "person",
                              field: .name, focused: $focused)

                    authField("Email (optional)", text: $email, icon: "envelope",
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
                    Text("Create Account")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(ScaleButtonStyle(scale: 0.96))
                .padding(.horizontal, 28)
                .padding(.bottom, 48)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func attemptSignUp() {
        guard password == confirmPassword else { errorMessage = "Passwords don't match."; return }
        guard password.count >= 4         else { errorMessage = "Password must be at least 4 characters."; return }
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { errorMessage = "Please enter a display name."; return }
        if authManager.signUp(name: name, email: email, password: password) {
            dismiss()
        } else {
            errorMessage = "Sign up failed. Please try again."
        }
    }
}

// MARK: - Log in

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss

    @State private var nameOrEmail  = ""
    @State private var password     = ""
    @State private var errorMessage = ""
    @State private var showPassword = false

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
                    authField("Name or Email", text: $nameOrEmail, icon: "person",
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
                    Text("Log In")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(ScaleButtonStyle(scale: 0.96))
                .padding(.horizontal, 28)
                .padding(.bottom, 48)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func attemptLogin() {
        guard authManager.login(nameOrEmail: nameOrEmail, password: password) else {
            errorMessage = "Incorrect name or password."
            return
        }
        dismiss()
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
