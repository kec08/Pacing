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
                    VStack(spacing: 12) {
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

                        // 카카오 로그인
                        Button {
                            Task {
                                await authVM.signInWithKakao(appState: appState)
                                if appState.isLoggedIn { navigateToOnboarding = true }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "message.fill")
                                    .font(.system(size: 16))
                                Text("카카오로 계속하기")
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color(red: 0.133, green: 0.133, blue: 0.133))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(red: 1.0, green: 0.898, blue: 0.0))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        // 구글 로그인
                        Button {
                            Task {
                                await authVM.signInWithGoogle(appState: appState)
                                if appState.isLoggedIn {
                                    navigateToOnboarding = true
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "g.circle.fill")
                                    .font(.system(size: 18))
                                Text("Google로 계속하기")
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        Button {
                            Task {
                                await authVM.signInAnonymously(appState: appState)
                                if appState.isLoggedIn {
                                    navigateToOnboarding = true
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "person.fill.questionmark")
                                Text("게스트로 시작")
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                        }
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
