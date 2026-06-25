import SwiftUI
import MusicKit

struct OnboardingMusicView: View {
    @EnvironmentObject var appState: AppState
    @State private var navigateToProfile = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // 아이콘
            ZStack {
                Circle()
                    .fill(Color.sub300)
                    .frame(width: 120, height: 120)
                Image(systemName: "music.note")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.sub500)
            }

            Spacer().frame(height: 36)

            // 텍스트
            VStack(spacing: 12) {
                Text("Apple Music 연동이 필요해요")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.textPrimary)

                Text("주변 러너와 음악을 함께 들으려면\nApple Music 접근 권한이 필요해요")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Spacer()

            // 버튼
            VStack(spacing: 12) {
                Button {
                    Task {
                        await MusicAuthorization.request()
                        navigateToProfile = true
                    }
                } label: {
                    Text("허용하기")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.sub500)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    navigateToProfile = true
                } label: {
                    Text("나중에 하기")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .background(Color.backgroundPrimary)
        .navigationDestination(isPresented: $navigateToProfile) {
            ProfileSetupView()
        }
    }
}
