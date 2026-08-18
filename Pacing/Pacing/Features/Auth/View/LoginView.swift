import SwiftUI
import AuthenticationServices
import CryptoKit
import Combine

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var authVM = AuthViewModel()
    @State private var navigateToOnboarding = false
    @State private var navigateToEmailLogin = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundSecondary
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: 0) {
                        Image("PacingLoginAppIcon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 82, height: 82)
                            .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))

                        Spacer().frame(height: 20)

                        Text("Pacing")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(Color.textPrimary)

                        Spacer().frame(height: 8)

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
                        Button {
                            authVM.errorMessage = nil
                            navigateToEmailLogin = true
                        } label: {
                            HStack(spacing: 8) {
                                Image("PacingAuthMark")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 22, height: 22)
                                Text("Pacing으로 로그인")
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.main500)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .accessibilityHint("이메일과 비밀번호로 로그인합니다")

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

                        // Google 로그인
                        Button {
                            Task {
                                await authVM.signInWithGoogle(appState: appState)
                                if appState.isLoggedIn {
                                    navigateToOnboarding = true
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image("GoogleLoginMark")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                                Text("Google로 계속하기")
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        // 카카오 로그인
                        Button {
                            Task {
                                await authVM.signInWithKakao(appState: appState)
                                if appState.isLoggedIn { navigateToOnboarding = true }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image("KakaoLoginMark")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                                Text("카카오로 계속하기")
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color(red: 0.133, green: 0.133, blue: 0.133))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(red: 1.0, green: 0.898, blue: 0.0))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        // 네이버 로그인
                        Button {
                            Task {
                                await authVM.signInWithNaver(appState: appState)
                                if appState.isLoggedIn { navigateToOnboarding = true }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image("NaverLoginMark")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 30, height: 30)
                                Text("네이버로 계속하기")
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(red: 0, green: 0.78, blue: 0.235))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    }

                    if let error = authVM.errorMessage {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.accent500)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationDestination(isPresented: $navigateToOnboarding) {
                OnboardingPermissionView()
                    .navigationBarBackButtonHidden(true)
            }
            .navigationDestination(isPresented: $navigateToEmailLogin) {
                EmailLoginView(authViewModel: authVM) {
                    navigateToEmailLogin = false
                    navigateToOnboarding = true
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active && authVM.isLoading {
                    // 외부 로그인(네이버 등) 취소 후 앱으로 돌아왔을 때 로딩 해제
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        if authVM.isLoading { authVM.isLoading = false }
                    }
                }
            }
        }
    }
}
