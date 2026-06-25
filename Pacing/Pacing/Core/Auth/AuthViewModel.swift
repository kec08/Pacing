import SwiftUI
import Combine
import FirebaseAuth
import AuthenticationServices
import CryptoKit

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var currentNonce: String?

    // MARK: - Apple 로그인 요청
    func handleSignInWithApple(_ result: Result<ASAuthorization, Error>, appState: AppState) async {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let auth):
            guard
                let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                let nonce = currentNonce,
                let tokenData = credential.identityToken,
                let tokenString = String(data: tokenData, encoding: .utf8)
            else { return }

            isLoading = true
            let firebaseCredential = OAuthProvider.appleCredential(
                withIDToken: tokenString,
                rawNonce: nonce,
                fullName: credential.fullName
            )

            do {
                try await Auth.auth().signIn(with: firebaseCredential)
                appState.isLoggedIn = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    // MARK: - 로그아웃
    func signOut(appState: AppState) {
        try? Auth.auth().signOut()
        appState.isLoggedIn = false
        appState.isProfileComplete = false
    }

    // MARK: - 현재 유저 UID
    var currentUID: String? {
        Auth.auth().currentUser?.uid
    }

    // MARK: - 세션 복원
    func restoreSession(appState: AppState) {
        if Auth.auth().currentUser != nil {
            appState.isLoggedIn = true
            let profileComplete = UserDefaults.standard.bool(forKey: "isProfileComplete")
            appState.isProfileComplete = profileComplete
        }
    }

    // MARK: - Nonce 생성
    func prepareNonce() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }

    private func randomNonceString(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
