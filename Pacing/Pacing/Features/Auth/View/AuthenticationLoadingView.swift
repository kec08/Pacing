import SwiftUI

struct AuthenticationLoadingView: View {
    var body: some View {
        ZStack {
            Color.backgroundSecondary
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 0) {
                    Image("PacingLoginAppIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                    Spacer().frame(height: 24)

                    Text("Pacing")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(Color.textPrimary)

                    Spacer().frame(height: 10)

                    Text("같은 비트, 같은 페이스")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()

                ProgressView()
                    .controlSize(.large)
                    .scaleEffect(1.25)
                    .tint(Color.textSecondary)
                    .padding(.bottom, 132)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("로그인 중")
    }
}
