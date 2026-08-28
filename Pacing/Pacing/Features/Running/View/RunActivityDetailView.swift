import SwiftUI
import MapKit
import CoreLocation

struct RunActivityDetailView: View {
    let record: RunRecord

    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                activityHeader
                distanceSection
                routeSection
                splitSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .background(Color.backgroundSecondary)
        .navigationTitle("활동 상세")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: fitRoute)
    }

    private var activityHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(startedAtText)
                .font(.system(size: 14))
                .foregroundStyle(Color.textSecondary)

            Text("러닝")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.textPrimary)
        }
    }

    private var distanceSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: "%.2f", record.distance))
                    .font(.system(size: 58, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)
                    .accessibilityLabel("거리 \(String(format: "%.2f", record.distance)) 킬로미터")

                Text("킬로미터")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
            }

            Divider()
                .padding(.vertical, 20)

            metricsSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(Color.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var metricsSection: some View {
        VStack(spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                compactMetric(value: formattedPace(record.displayPace), label: "평균 페이스")
                compactMetric(value: formattedDuration(record.duration), label: "시간")
                compactMetric(value: "\(estimatedCalories)", label: "칼로리")
            }
            HStack(alignment: .top, spacing: 12) {
                compactMetric(value: formattedElevation, label: "고도 상승")
                compactMetric(value: formattedHeartRate, label: "BPM")
                compactMetric(value: "--", label: "케이던스")
            }
        }
    }

    private func compactMetric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var routeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("러닝 경로")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.textPrimary)

            Group {
                if record.routeCoordinates.count >= 2 {
                    Map(position: $cameraPosition, interactionModes: []) {
                        ForEach(routeGradientSegments) { segment in
                            MapPolyline(coordinates: segment.coordinates)
                                .stroke(
                                    segment.color,
                                    style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                                )
                        }

                        Annotation("출발", coordinate: record.routeCoordinates[0], anchor: .bottom) {
                            RouteEndpointLabel(title: "출발", tint: Color.main500)
                        }
                        Annotation("도착", coordinate: record.routeCoordinates[record.routeCoordinates.count - 1], anchor: .bottom) {
                            RouteEndpointLabel(title: "도착", tint: Color.sub500)
                        }
                    }
                    .mapStyle(.standard)
                    .allowsHitTesting(false)
                    .accessibilityLabel("러닝 이동 경로 지도")
                } else {
                    ContentUnavailableView(
                        "저장된 경로가 없어요",
                        systemImage: "map",
                        description: Text("이 기록은 위치 경로를 저장하지 않았습니다.")
                    )
                    .foregroundStyle(Color.textSecondary)
                }
            }
            .frame(height: 270)
            .frame(maxWidth: .infinity)
            .background(Color.backgroundPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private var splitSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("구간별 페이스")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.textPrimary)

            if displayLapPaces.isEmpty {
                Text("1km 이상 달리면 구간별 페이스가 표시돼요.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(Color.backgroundPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                if record.lapPaces.isEmpty {
                    Text("이전 기록은 평균 페이스 기준으로 표시됩니다.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                }

                VStack(spacing: 8) {
                    ForEach(displayLapPaces) { lap in
                        splitRow(lap)
                    }
                }
            }
        }
    }

    private var displayLapPaces: [RunLapPace] {
        if !record.lapPaces.isEmpty { return record.lapPaces }

        let completedKilometers = Int(record.distance.rounded(.down))
        guard completedKilometers > 0, record.isPaceValid else { return [] }

        return (1...completedKilometers).map {
            RunLapPace(kilometer: $0, pace: record.avgPace)
        }
    }

    private var routeGradientSegments: [RunRouteGradientSegment] {
        RunRouteGradient.segments(from: record.routeCoordinates)
    }

    private func splitRow(_ lap: RunLapPace) -> some View {
        HStack(spacing: 14) {
            Text("\(lap.kilometer) km")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: 56, alignment: .leading)

            Spacer(minLength: 0)

            Text(formattedPace(lap.pace))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color.textPrimary)
                .frame(width: 58, alignment: .trailing)
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 56)
        .background(Color.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(lap.kilometer) 킬로미터, 평균 페이스 \(formattedPace(lap.pace))")
    }

    private var startedAtText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일 EEEE · a h:mm"
        return formatter.string(from: record.startedAt)
    }

    private var estimatedCalories: Int {
        let storedWeight = UserDefaults.standard.integer(forKey: "weight")
        let weight = storedWeight > 0 ? Double(storedWeight) : 60.0
        return Int((weight * record.distance * 1.036).rounded())
    }

    private var formattedElevation: String {
        guard let value = record.elevationGainMeters, value.isFinite else { return "--" }
        return "\(Int(value.rounded())) m"
    }

    private var formattedHeartRate: String {
        guard let value = record.averageHeartRate, value.isFinite else { return "--" }
        return "\(Int(value.rounded()))"
    }

    private func formattedDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
            : String(format: "%d:%02d", minutes, remainingSeconds)
    }

    private func formattedPace(_ pace: Double) -> String {
        guard pace > 0 else { return "--'--\"" }
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d'%02d\"", minutes, seconds)
    }

    private func fitRoute() {
        guard let region = RunRouteBounds.region(
            for: record.routeCoordinates,
            paddingMultiplier: 1.4,
            minimumDelta: 0.003
        ) else { return }
        cameraPosition = .region(region)
    }
}

private struct RouteEndpointLabel: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.backgroundPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(tint.opacity(0.35), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.16), radius: 4, x: 0, y: 2)
            .accessibilityLabel(title)
    }
}
