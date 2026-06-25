import SwiftUI
import AuthenticationServices

struct AppleSignInButton: View {
    let onCompletion: (Result<ASAuthorization, Error>) -> Void
    let prepareNonce: () -> String

    var body: some View {
        SignInWithAppleButton(.continue) { request in
            request.requestedScopes = [.fullName, .email]
            request.nonce = prepareNonce()
        } onCompletion: { result in
            onCompletion(result)
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 54)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black)
                .overlay(
                    HStack(spacing: 8) {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Apple로 계속하기")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                )
                .allowsHitTesting(false)
        )
    }
}
