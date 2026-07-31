import SwiftUI

struct RunSplitPaceView: View {
    let record: RunRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if record.lapPaces.isEmpty {
                    ContentUnavailableView(
                        "구간 기록이 없어요",
                        systemImage: "stopwatch",
                        description: Text("이전 러닝 기록은 km별 페이스를 저장하지 않았습니다."))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 56)
                        .background(Color.backgroundPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                } else {
                    VStack(spacing: 10) {
                        ForEach(record.lapPaces) { lap in
                            splitRow(lap)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Color.backgroundSecondary)
        .navigationTitle("구간")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("km별 평균 페이스")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.textPrimary)
            Text("각 1km를 완료한 시점의 페이스예요.")
                .font(.system(size: 14))
                .foregroundStyle(Color.textSecondary)
        }
    }

    private func splitRow(_ lap: RunLapPace) -> some View {
        HStack(spacing: 14) {
            Text("\(lap.kilometer) km")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: 58, alignment: .leading)
                .accessibilityLabel("\(lap.kilometer) 킬로미터")

            GeometryReader { proxy in
                Capsule()
                    .fill(Color.gray100)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(LinearGradient(colors: [Color.main500, Color.main300], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(proxy.size.width * barRatio(for: lap), 42))
                    }
            }
            .frame(height: 12)

            Text(formattedPace(lap.pace))
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Color.textPrimary)
                .frame(width: 58, alignment: .trailing)
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 60)
        .background(Color.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(lap.kilometer) 킬로미터, 평균 페이스 \(formattedPace(lap.pace))")
    }

    private func barRatio(for lap: RunLapPace) -> CGFloat {
        guard let slowest = record.lapPaces.map(\.pace).max(), slowest > 0 else { return 1 }
        return CGFloat(min(max(slowest / lap.pace, 0.45), 1))
    }

    private func formattedPace(_ pace: Double) -> String {
        guard pace > 0 else { return "--'--\"" }
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d'%02d\"", minutes, seconds)
    }
}
