import SwiftUI

struct RunHistoryCard: View {
    let record: RunRecord
    let vm: MyViewModel

    private var dateString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy. M. d."
        return f.string(from: record.startedAt)
    }

    private var startTimeString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "a h시 m분"
        return f.string(from: record.startedAt)
    }

    var body: some View {
        HStack(spacing: 14) {
            // 썸네일 placeholder
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray100)
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "map.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.gray300)
                )

            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dateString)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    Text(startTimeString)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                }

                HStack(spacing: 16) {
                    statItem(value: String(format: "%.2f", record.distance), unit: "km")
                    statItem(value: vm.formattedPace(record.avgPace), unit: "페이스")
                    statItem(value: vm.formattedDuration(record.duration), unit: "시간")
                }
            }

            Spacer()
        }
        .padding(14)
        .background(Color.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    private func statItem(value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.textPrimary)
            Text(unit)
                .font(.system(size: 11))
                .foregroundStyle(Color.textSecondary)
        }
    }
}
