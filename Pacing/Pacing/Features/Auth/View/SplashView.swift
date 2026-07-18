import SwiftUI
import FirebaseAuth

struct SplashView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isLoading = true
    @State private var isExiting = false
    @State private var didStartRestoration = false

    var body: some View {
        Group {
            if isLoading || appState.isAuthLoading {
                ZStack {
                    splashGradient.ignoresSafeArea()

                    Image("PacingSplashMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 176, height: 176)
                        .scaleEffect(isExiting ? 0.28 : 1)
                        .opacity(isExiting ? 0 : 1)
                        .accessibilityLabel("Pacing")
                }
            } else if appState.isLoggedIn {
                if appState.isProfileComplete {
                    MainTabView()
                } else {
                    ProfileSetupView()
                }
            } else {
                LoginView()
            }
        }
        .onAppear {
            guard !didStartRestoration else { return }
            didStartRestoration = true
            restoreSession()
        }
    }

    private var splashGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.main500,
                Color(red: 0.85, green: 0.12, blue: 0.55),
                Color(red: 0.42, green: 0.19, blue: 0.90)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func restoreSession() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            guard let uid = Auth.auth().currentUser?.uid else {
                completeSplash(isLoggedIn: false, isProfileComplete: false)
                return
            }
            Task { @MainActor in
                let exists = await FirestoreService.shared.hasUserProfile(uid: uid)
                if exists {
                    completeSplash(isLoggedIn: true, isProfileComplete: true)
                } else {
                    // 프로필 없는 유저 → 로그아웃 후 로그인 화면
                    try? Auth.auth().signOut()
                    completeSplash(isLoggedIn: false, isProfileComplete: false)
                }
            }
        }
    }

    private func completeSplash(isLoggedIn: Bool, isProfileComplete: Bool) {
        appState.isLoggedIn = isLoggedIn
        appState.isProfileComplete = isProfileComplete

        guard !reduceMotion else {
            isLoading = false
            return
        }

        withAnimation(.easeInOut(duration: 0.32)) {
            isExiting = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            isLoading = false
        }
    }
}
