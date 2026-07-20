import SwiftUI

struct SignUpView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var authViewModel: AuthViewModel
    let onSignUpSuccess: () -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var passwordConfirmation = ""
    @State private var isPasswordVisible = false
    @State private var isConfirmationVisible = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Pacing 회원가입")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                    .padding(.top, 36)

                Text("가입 후 이름과 신체 정보를 입력해주세요")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.textSecondary)
                    .padding(.top, 8)

                VStack(spacing: 16) {
                    AuthTextField(title: "이메일", placeholder: "name@example.com", text: $email, contentType: .emailAddress)
                    AuthTextField(
                        title: "비밀번호",
                        placeholder: "8자 이상 입력하세요",
                        text: $password,
                        contentType: .newPassword,
                        isSecure: !isPasswordVisible,
                        showsPasswordToggle: true,
                        isPasswordVisible: $isPasswordVisible
                    )
                    AuthTextField(
                        title: "비밀번호 확인",
                        placeholder: "비밀번호를 다시 입력하세요",
                        text: $passwordConfirmation,
                        contentType: .newPassword,
                        isSecure: !isConfirmationVisible,
                        showsPasswordToggle: true,
                        isPasswordVisible: $isConfirmationVisible
                    )
                }
                .padding(.top, 40)

                if let errorMessage = authViewModel.errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.accent500)
                        .padding(.top, 14)
                        .accessibilityLabel("회원가입 오류: \(errorMessage)")
                }

                Button(action: signUp) {
                    Group {
                        if authViewModel.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("회원가입하고 시작하기")
                        }
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.main500)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(authViewModel.isLoading)
                .padding(.top, 32)
                .accessibilityHint("이메일 계정을 만들고 프로필 설정을 시작합니다")
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
        .background(Color.backgroundPrimary)
        .navigationTitle("회원가입")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            authViewModel.errorMessage = nil
        }
    }

    private func signUp() {
        Task {
            await authViewModel.signUpWithEmail(
                email: email,
                password: password,
                confirmation: passwordConfirmation,
                appState: appState
            )
            if appState.isLoggedIn {
                onSignUpSuccess()
            }
        }
    }
}
