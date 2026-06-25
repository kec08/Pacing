import SwiftUI

struct WeeklyStatsCard: View {
    let stats: WeeklyStats
    let vm: HomeViewModel

    var body: some View {
        HStack(spacing: 0) {
            statItem(value: vm.formatDistance(stats.totalDistance), label: "거리")
            divider
            statItem(value: vm.formatDuration(stats.totalDuration), label: "시간")
            divider
            statItem(value: vm.formatPace(stats.avgPace), label: "평균 페이스")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.textPrimary)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.dividerPrimary)
            .frame(width: 1, height: 36)
    }
}
