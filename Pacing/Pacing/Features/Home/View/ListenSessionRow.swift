import SwiftUI

struct ListenSessionRow: View {
    let session: ListenSession
    let vm: HomeViewModel

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color.sub300)
                .frame(width: 44, height: 44)
                .overlay {
                    Text(String(vm.listenPartnerNickname(session).prefix(1)))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.sub500)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(vm.listenPartnerNickname(session))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                Text("같이 들은 시간 · \(vm.formatListenTime(session.date))")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                if !session.songTitle.isEmpty {
                    Text(session.songTitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                }

                Text(vm.formatDate(session.date))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(14)
        .background(Color.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
