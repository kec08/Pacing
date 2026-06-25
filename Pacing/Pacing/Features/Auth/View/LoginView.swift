import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // 로고 영역
            VStack(spacing: 12) {
                Image(systemName: "figure.run.circle.fill")
                    .resizable()
                    .frame(width: 72, height: 72)
                    .foregroundStyle(.main500)

                Text("Pacing")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.textPrimary)

                Text("같은 비트, 같은 페이스")
                    .font(.system(size: 16))
                    .foregroundStyle(.textSecondary)
            }

            Spacer()

            // Apple 로그인 버튼 (임시 — Firebase 연동 전)
            Button {
                // TODO: Apple 로그인 연동
                appState.isLoggedIn = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "applelogo")
                    Text("Apple로 로그인")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .background(Color.backgroundPrimary)
    }
}
