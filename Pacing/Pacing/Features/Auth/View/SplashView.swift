import SwiftUI

struct SplashView: View {
    @EnvironmentObject var appState: AppState
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                // 로고 스플래시
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
        // UserDefaults에서 로그인/프로필 완료 상태 복원
        // Firebase 연동 전 임시 처리
        let loggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
        let profileComplete = UserDefaults.standard.bool(forKey: "isProfileComplete")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            appState.isLoggedIn = loggedIn
            appState.isProfileComplete = profileComplete
            isLoading = false
        }
    }
}
