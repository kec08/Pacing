import SwiftUI
import CoreLocation

struct OnboardingPermissionView: View {
    @EnvironmentObject var appState: AppState
    @State private var locationManager = CLLocationManager()
    @State private var navigateToMusic = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // 아이콘
            ZStack {
                Circle()
                    .fill(Color.main200)
                    .frame(width: 120, height: 120)
                Image(systemName: "location.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.main500)
            }

            Spacer().frame(height: 36)

            // 텍스트
            VStack(spacing: 12) {
                Text("위치 권한이 필요해요")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.textPrimary)

                Text("주변 러너를 찾고 러닝 경로를 기록하려면\n위치 접근이 항상 허용되어야 해요")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Spacer()

            // 버튼
            VStack(spacing: 12) {
                Button {
                    locationManager.requestAlwaysAuthorization()
                    navigateToMusic = true
                } label: {
                    Text("허용하기")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.main500)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    navigateToMusic = true
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
        .navigationDestination(isPresented: $navigateToMusic) {
            OnboardingMusicView()
        }
    }
}
