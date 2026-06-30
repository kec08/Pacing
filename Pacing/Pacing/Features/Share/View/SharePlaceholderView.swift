import SwiftUI

struct SharePlaceholderView: View {
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("공유")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                    Text("러닝 플레이리스트 공유 기능은 다음 단계에서 연결됩니다")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()

                VStack(spacing: 14) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(Color.main500)
                    Text("공유 탭 준비 중")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    Text("친구 탭 MVP 이후 Apple Music 플레이리스트 탐색과 내 공유 기능을 구현합니다.")
                        .font(.system(size: 14))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 34)
                .padding(.horizontal, 20)
                .background(Color.backgroundPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.backgroundSecondary)
            .navigationBarHidden(true)
        }
    }
}
