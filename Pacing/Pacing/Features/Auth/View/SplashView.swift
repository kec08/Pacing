import SwiftUI

struct SplashView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if appState.isLoggedIn {
                if appState.isProfileComplete {
                    MainTabView()
                } else {
                    ProfileSetupView()
                }
            } else {
                LoginView()
            }
        }
    }
}
