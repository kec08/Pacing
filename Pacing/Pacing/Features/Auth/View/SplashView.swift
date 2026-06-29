import SwiftUI
import FirebaseAuth

struct SplashView: View {
    @EnvironmentObject var appState: AppState
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
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
            if Auth.auth().currentUser != nil {
                appState.isLoggedIn = true
                appState.isProfileComplete = UserDefaults.standard.bool(forKey: "isProfileComplete")
            } else {
                appState.isLoggedIn = false
                appState.isProfileComplete = false
            }
            isLoading = false
        }
    }
}
