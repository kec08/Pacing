import SwiftUI
import FirebaseAuth

struct SplashView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isLoading = true
    @State private var isBrandVisible = false

    var body: some View {
        Group {
            if isLoading || appState.isAuthLoading {
                ZStack {
                    Color.pacingGradient.ignoresSafeArea()

                    VStack(spacing: 18) {
                        PacingBrandMark(size: 112)
                            .scaleEffect(isBrandVisible ? 1 : 0.88)
                            .opacity(isBrandVisible ? 1 : 0)

                        Text("Pacing")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .opacity(isBrandVisible ? 1 : 0)

                        Text("RUN YOUR RHYTHM")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(1.8)
                            .foregroundStyle(.white.opacity(0.78))
                            .opacity(isBrandVisible ? 1 : 0)
                    }
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
            if reduceMotion {
                isBrandVisible = true
            } else {
                withAnimation(.easeOut(duration: 0.42)) {
                    isBrandVisible = true
                }
            }
            restoreSession()
        }
    }

    private func restoreSession() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            guard let uid = Auth.auth().currentUser?.uid else {
                appState.isLoggedIn = false
                appState.isProfileComplete = false
                isLoading = false
                return
            }
            Task { @MainActor in
                let exists = await FirestoreService.shared.hasUserProfile(uid: uid)
                if exists {
                    appState.isLoggedIn = true
                    appState.isProfileComplete = true
                } else {
                    // 프로필 없는 유저 → 로그아웃 후 로그인 화면
                    try? Auth.auth().signOut()
                    appState.isLoggedIn = false
                    appState.isProfileComplete = false
                }
                isLoading = false
            }
        }
    }
}
