import SwiftUI

struct RecentRunRow: View {
    let run: RunRecord
    let vm: HomeViewModel

    var body: some View {
        HStack(spacing: 14) {
            // 썸네일 placeholder
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray100)
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: "map.fill")
                        .foregroundStyle(Color.gray400)
                        .font(.system(size: 20))
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(vm.formatDate(run.startedAt))
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
                HStack(spacing: 12) {
                    Label(vm.formatDistance(run.distance), systemImage: "figure.run")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    Text(vm.formatDuration(run.duration))
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textSecondary)
                    Text(vm.formatPace(run.avgPace) + "/km")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textSecondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.gray300)
        }
        .padding(14)
        .background(Color.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
