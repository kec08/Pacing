import SwiftUI

struct EmailLoginView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var authViewModel: AuthViewModel
    let onLoginSuccess: () -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    @State private var isShowingSignUp = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Pacing으로 로그인")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                    .padding(.top, 36)

                Text("이메일과 비밀번호를 입력해주세요")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.textSecondary)
                    .padding(.top, 8)

                VStack(spacing: 16) {
                    AuthTextField(title: "이메일", placeholder: "name@example.com", text: $email, contentType: .emailAddress)
                    AuthTextField(
                        title: "비밀번호",
                        placeholder: "비밀번호를 입력하세요",
                        text: $password,
                        contentType: .password,
                        isSecure: !isPasswordVisible,
                        showsPasswordToggle: true,
                        isPasswordVisible: $isPasswordVisible
                    )
                }
                .padding(.top, 40)

                if let errorMessage = authViewModel.errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.accent500)
                        .padding(.top, 14)
                        .accessibilityLabel("로그인 오류: \(errorMessage)")
                }

                Button(action: signIn) {
                    Group {
                        if authViewModel.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("로그인")
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
                .accessibilityHint("입력한 이메일과 비밀번호로 로그인합니다")

                HStack(spacing: 4) {
                    Text("아직 회원이 아니신가요?")
                        .foregroundStyle(Color.textSecondary)
                    Button("회원가입") {
                        authViewModel.errorMessage = nil
                        isShowingSignUp = true
                    }
                    .foregroundStyle(Color.main500)
                    .fontWeight(.semibold)
                }
                .font(.system(size: 15))
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
        .background(Color.backgroundPrimary)
        .navigationTitle("로그인")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $isShowingSignUp) {
            SignUpView(authViewModel: authViewModel, onSignUpSuccess: onLoginSuccess)
        }
        .onDisappear {
            authViewModel.errorMessage = nil
        }
    }

    private func signIn() {
        Task {
            await authViewModel.signInWithEmail(email: email, password: password, appState: appState)
            if appState.isLoggedIn {
                onLoginSuccess()
            }
        }
    }
}

struct AuthTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let contentType: UITextContentType
    var isSecure = false
    var showsPasswordToggle = false
    @Binding var isPasswordVisible: Bool

    init(
        title: String,
        placeholder: String,
        text: Binding<String>,
        contentType: UITextContentType,
        isSecure: Bool = false,
        showsPasswordToggle: Bool = false,
        isPasswordVisible: Binding<Bool> = .constant(false)
    ) {
        self.title = title
        self.placeholder = placeholder
        _text = text
        self.contentType = contentType
        self.isSecure = isSecure
        self.showsPasswordToggle = showsPasswordToggle
        _isPasswordVisible = isPasswordVisible
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.textSecondary)

            HStack(spacing: 8) {
                Group {
                    if isSecure {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .textContentType(contentType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(contentType == .emailAddress ? .emailAddress : .default)

                if showsPasswordToggle {
                    Button {
                        isPasswordVisible.toggle()
                    } label: {
                        Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                            .foregroundStyle(Color.textSecondary)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(isPasswordVisible ? "비밀번호 숨기기" : "비밀번호 보기")
                }
            }
            .padding(.leading, 16)
            .padding(.trailing, showsPasswordToggle ? 4 : 16)
            .frame(height: 52)
            .background(Color.gray100)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}
