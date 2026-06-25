import SwiftUI
import AuthenticationServices
import CryptoKit

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var authVM = AuthViewModel()
    @State private var navigateToOnboarding = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "figure.run.circle.fill")
                        .resizable()
                        .frame(width: 72, height: 72)
                        .foregroundStyle(Color.main500)

                    Text("Pacing")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(Color.textPrimary)

                    Text("같은 비트, 같은 페이스")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()

                if authVM.isLoading {
                    ProgressView()
                        .padding(.bottom, 48)
                } else {
                    AppleSignInButton { result in
                        Task {
                            await authVM.handleSignInWithApple(result, appState: appState)
                            if appState.isLoggedIn {
                                navigateToOnboarding = true
                            }
                        }
                    } prepareNonce: {
                        authVM.prepareNonce()
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
                }

                if let error = authVM.errorMessage {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.accent500)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                }
            }
            .background(Color.backgroundPrimary)
            .navigationDestination(isPresented: $navigateToOnboarding) {
                OnboardingPermissionView()
                    .navigationBarBackButtonHidden(true)
            }
        }
    }
}
