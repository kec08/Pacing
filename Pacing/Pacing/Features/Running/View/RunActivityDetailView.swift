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
                metricsSection
                routeSection
                splitLink
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
        VStack(alignment: .leading, spacing: 4) {
            Text(String(format: "%.2f", record.distance))
                .font(.system(size: 58, weight: .bold, design: .rounded))
                .foregroundStyle(Color.textPrimary)
                .accessibilityLabel("거리 \(String(format: "%.2f", record.distance)) 킬로미터")

            Text("킬로미터")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(Color.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var metricsSection: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            alignment: .leading,
            spacing: 1
        ) {
            metric(value: formattedPace(record.avgPace), label: "평균 페이스")
            metric(value: formattedDuration(record.duration), label: "시간")
            metric(value: "\(estimatedCalories)", label: "칼로리")
            metric(value: "\(record.lapPaces.count)", label: "완료 구간")
        }
        .background(Color.gray200)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func metric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .padding(18)
        .background(Color.backgroundPrimary)
        .accessibilityElement(children: .combine)
    }

    private var routeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("러닝 경로")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.textPrimary)

            Group {
                if record.routeCoordinates.count >= 2 {
                    Map(position: $cameraPosition, interactionModes: [.pan, .zoom]) {
                        MapPolyline(coordinates: record.routeCoordinates)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.main500, Color.sub500],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                            )

                        Marker("출발", coordinate: record.routeCoordinates[0])
                            .tint(Color.main500)
                        Marker("도착", coordinate: record.routeCoordinates[record.routeCoordinates.count - 1])
                            .tint(Color.sub500)
                    }
                    .mapStyle(.standard)
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

    private var splitLink: some View {
        NavigationLink {
            RunSplitPaceView(record: record)
        } label: {
            HStack {
                Label("구간별 페이스", systemImage: "chart.bar.fill")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(Color.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 54)
            .padding(.horizontal, 18)
            .background(Color.backgroundPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint("킬로미터별 페이스를 확인합니다")
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
        guard record.routeCoordinates.count >= 2 else { return }

        let latitudes = record.routeCoordinates.map(\.latitude)
        let longitudes = record.routeCoordinates.map(\.longitude)
        guard let minLatitude = latitudes.min(), let maxLatitude = latitudes.max(),
              let minLongitude = longitudes.min(), let maxLongitude = longitudes.max() else {
            return
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLatitude + maxLatitude) / 2,
            longitude: (minLongitude + maxLongitude) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLatitude - minLatitude) * 1.4, 0.003),
            longitudeDelta: max((maxLongitude - minLongitude) * 1.4, 0.003)
        )
        cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
    }
}

