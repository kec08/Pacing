import SwiftUI
import FirebaseAuth

struct SplashView: View {
    @EnvironmentObject var appState: AppState
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading || appState.isAuthLoading {
                ZStack {
                    Color.backgroundPrimary.ignoresSafeArea()
                    VStack(spacing: 16) {
                        Image(systemName: "figure.run.circle.fill")
                            .resizable()
                            .frame(width: 80, height: 80)
                            .foregroundStyle(Color.main500)
                        Text("Pacing")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
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
