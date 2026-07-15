import SwiftUI
import Combine
import FirebaseAuth
import FirebaseCore
import FirebaseFunctions
import AuthenticationServices
import CryptoKit
import NaverThirdPartyLogin
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif
#if canImport(KakaoSDKCommon)
import KakaoSDKCommon
import KakaoSDKAuth
import KakaoSDKUser
#endif

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isLoading = false  // LoginView에서 scenePhase 감지로 리셋 가능
    @Published var errorMessage: String?

    private var currentNonce: String?

    // MARK: - Apple 로그인 요청
    func handleSignInWithApple(_ result: Result<ASAuthorization, Error>, appState: AppState) async {
        switch result {
        case .failure(let error):
            let msg = Self.koreanAuthError(error)
            if let msg { errorMessage = msg }
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
                appState.isAuthLoading = true
                await restoreProfile(appState: appState)
                appState.isAuthLoading = false
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    // MARK: - 익명 로그인 (테스트용)
    func signInAnonymously(appState: AppState) async {
        isLoading = true
        do {
            try await Auth.auth().signInAnonymously()
            appState.isLoggedIn = true
            appState.isAuthLoading = true
            await restoreProfile(appState: appState)
            appState.isAuthLoading = false
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - 구글 로그인
    // static으로 유지 → async suspension 중 ARC 해제 방지
    nonisolated(unsafe) private static var _googleSignInWindow: UIWindow?

    func signInWithGoogle(appState: AppState) async {
        #if canImport(GoogleSignIn)
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "Firebase clientID를 찾을 수 없어요"
            return
        }
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let keyWindow = scene.windows.first(where: { $0.isKeyWindow }),
              let rootVC = keyWindow.rootViewController
        else {
            errorMessage = "화면을 표시할 수 없어요"
            return
        }

        isLoading = true
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "구글 토큰을 가져오지 못했어요"
                isLoading = false
                return
            }
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            try await Auth.auth().signIn(with: credential)
            appState.isLoggedIn = true
            appState.isAuthLoading = true
            await restoreProfile(appState: appState)
            appState.isAuthLoading = false
        } catch {
            if let msg = Self.koreanAuthError(error) { errorMessage = msg }
        }
        isLoading = false
        #else
        errorMessage = "GoogleSignIn SDK가 설치되지 않았어요"
        #endif
    }

    // MARK: - 프로필 복원 (재로그인 시 재입력 방지)
    /// 로그인 성공 후 Firestore에 프로필이 있으면 UserDefaults에 복원하고 isProfileComplete = true.
    /// 신규 유저(프로필 없음)면 isProfileComplete = false → 프로필 설정 화면으로.
    func restoreProfile(appState: AppState) async {
        guard let uid = Auth.auth().currentUser?.uid else {
            appState.isProfileComplete = false
            return
        }
        let d = UserDefaults.standard
        // 계정 전환 잔상 방지: 항상 비우고 새 계정 값으로 채움
        ["nickname", "height", "weight", "age", "profileImageBase64"].forEach { d.removeObject(forKey: $0) }

        if let data = try? await FirestoreService.shared.fetchUserProfile(uid: uid),
           let nickname = data["nickname"] as? String,
           !nickname.trimmingCharacters(in: .whitespaces).isEmpty {
            d.set(nickname, forKey: "nickname")
            if let h = data["height"] as? Int { d.set(h, forKey: "height") }
            if let w = data["weight"] as? Int { d.set(w, forKey: "weight") }
            if let a = data["age"]    as? Int { d.set(a, forKey: "age") }
            if let img = data["profileImageBase64"] as? String { d.set(img, forKey: "profileImageBase64") }
            appState.isProfileComplete = true
        } else {
            appState.isProfileComplete = false
        }
    }

    // MARK: - 로그아웃
    func signOut(appState: AppState) {
        try? Auth.auth().signOut()
        appState.isLoggedIn = false
        appState.isProfileComplete = false
        // 다른 계정 로그인 시 이전 프로필 잔상 방지
        let d = UserDefaults.standard
        ["nickname", "height", "weight", "age", "profileImageBase64"].forEach { d.removeObject(forKey: $0) }
    }

    // MARK: - 네이버 로그인 (ASWebAuthenticationSession + Firebase Hosting 리다이렉트)
    nonisolated(unsafe) static var naverLoginCompletion: ((Result<String, Error>) -> Void)?
    nonisolated(unsafe) private static var _naverSession: ASWebAuthenticationSession?
    nonisolated(unsafe) private static var _naverContext: NaverPresentationContext?

    func signInWithNaver(appState: AppState) async {
        isLoading = true
        defer { isLoading = false; appState.isAuthLoading = false }

        let clientID = "hxrh7_6fG3iRc6tKxOuY"
        let redirectURI = "https://pacing-a8639.web.app/naver-callback"
        let state = UUID().uuidString.replacingOccurrences(of: "-", with: "")

        var comps = URLComponents(string: "https://nid.naver.com/oauth2.0/authorize")!
        comps.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id",     value: clientID),
            URLQueryItem(name: "redirect_uri",  value: redirectURI),
            URLQueryItem(name: "state",         value: state),
        ]
        guard let authURL = comps.url else { return }

        do {
            let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
                guard let scene = UIApplication.shared.connectedScenes
                    .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                      let window = scene.windows.first(where: { $0.isKeyWindow })
                else { continuation.resume(throwing: NSError(domain: "NaverLogin", code: -2)); return }

                let ctx = NaverPresentationContext(window: window)
                Self._naverContext = ctx

                let session = ASWebAuthenticationSession(
                    url: authURL, callbackURLScheme: "naverPacing"
                ) { url, error in
                    Self._naverSession = nil
                    Self._naverContext = nil
                    if let url        { continuation.resume(returning: url) }
                    else if let error { continuation.resume(throwing: error) }
                    else              { continuation.resume(throwing: NSError(domain: "NaverLogin", code: -1)) }
                }
                session.prefersEphemeralWebBrowserSession = false
                session.presentationContextProvider = ctx
                Self._naverSession = session
                session.start()
            }

            guard let parts = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                  let code  = parts.queryItems?.first(where: { $0.name == "code" })?.value
            else { errorMessage = "네이버 로그인에 실패했어요."; return }

            let functions = Functions.functions(region: "asia-northeast3")
            let result = try await functions.httpsCallable("naverLogin").call(["code": code, "state": state])
            guard let data        = result.data as? [String: Any],
                  let customToken = data["customToken"] as? String
            else { errorMessage = "네이버 로그인 응답이 올바르지 않아요."; return }

            try await Auth.auth().signIn(withCustomToken: customToken)
            appState.isLoggedIn = true
            appState.isAuthLoading = true
            await restoreProfile(appState: appState)
        } catch {
            let nsErr = error as NSError
            if nsErr.domain == ASWebAuthenticationSessionErrorDomain && nsErr.code == 1 { return }
            if let msg = Self.koreanAuthError(error) { errorMessage = msg }
        }
    }

    // MARK: - 카카오 로그인
    func signInWithKakao(appState: AppState) async {
        #if canImport(KakaoSDKUser)
        isLoading = true
        do {
            let accessToken = try await getKakaoAccessToken()
            // Cloud Functions 호출
            let functions = Functions.functions(region: "asia-northeast3")
            let result = try await functions.httpsCallable("kakaoLogin").call(["accessToken": accessToken])
            guard let data = result.data as? [String: Any],
                  let customToken = data["customToken"] as? String else {
                errorMessage = "카카오 로그인 응답이 올바르지 않아요."
                isLoading = false
                return
            }
            try await Auth.auth().signIn(withCustomToken: customToken)
            appState.isLoggedIn = true
            appState.isAuthLoading = true
            await restoreProfile(appState: appState)
            appState.isAuthLoading = false
        } catch {
            if let msg = Self.koreanAuthError(error) { errorMessage = msg }
        }
        isLoading = false
        #else
        errorMessage = "KakaoSDK가 설치되지 않았어요"
        #endif
    }

    #if canImport(KakaoSDKUser)
    private func getKakaoAccessToken() async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            // 카카오톡 앱 로그인 가능 여부 확인
            if UserApi.isKakaoTalkLoginAvailable() {
                UserApi.shared.loginWithKakaoTalk { token, error in
                    if let error { continuation.resume(throwing: error); return }
                    guard let token else {
                        continuation.resume(throwing: NSError(domain: "KakaoLogin", code: -1))
                        return
                    }
                    continuation.resume(returning: token.accessToken)
                }
            } else {
                // 카카오 계정으로 웹 로그인
                UserApi.shared.loginWithKakaoAccount { token, error in
                    if let error { continuation.resume(throwing: error); return }
                    guard let token else {
                        continuation.resume(throwing: NSError(domain: "KakaoLogin", code: -1))
                        return
                    }
                    continuation.resume(returning: token.accessToken)
                }
            }
        }
    }
    #endif

    // MARK: - 에러 한글 변환 (취소는 nil 반환 → 표시 안 함)
    private static func koreanAuthError(_ error: Error) -> String? {
        let code = (error as NSError).code
        // Apple: 1000=unknown(취소 포함), 1001=사용자 취소 / Google: -5=취소
        if code == 1000 || code == 1001 || code == -5 { return nil }
        switch code {
        case 17004: return "잘못된 인증 정보예요."
        case 17007: return "이미 가입된 이메일이에요."
        case 17008: return "이메일 형식이 올바르지 않아요."
        case 17009: return "비밀번호가 틀렸어요."
        case 17011: return "존재하지 않는 계정이에요."
        case 17020: return "네트워크 연결을 확인해주세요."
        case 17026: return "비밀번호가 너무 짧아요."
        default:    return "로그인 중 오류가 발생했어요. 다시 시도해주세요."
        }
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

// MARK: - ASWebAuthenticationSession context
final class NaverPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    private let window: UIWindow
    init(window: UIWindow) { self.window = window }
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor { window }
}

// MARK: - 네이버 SDK Delegate (requestThirdPartyLogin 미사용 시에도 SDK 초기화 필요)
final class NaverLoginDelegate: NSObject, NaverThirdPartyLoginConnectionDelegate {
    func oauth20ConnectionDidFinishRequestACTokenWithAuthCode() {
        guard let token = NaverThirdPartyLoginConnection.getSharedInstance()?.accessToken else {
            AuthViewModel.naverLoginCompletion?(.failure(NSError(domain: "NaverLogin", code: -1)))
            return
        }
        AuthViewModel.naverLoginCompletion?(.success(token))
    }

    func oauth20ConnectionDidFinishRequestACTokenWithRefreshToken() {}

    func oauth20ConnectionDidFinishDeleteToken() {}

    func oauth20Connection(_ oauthConnection: NaverThirdPartyLoginConnection!, didFailWithError error: Error!) {
        AuthViewModel.naverLoginCompletion?(.failure(error ?? NSError(domain: "NaverLogin", code: -2)))
    }
}


