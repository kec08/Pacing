import SwiftUI
import MapKit
import CoreLocation

struct RunSummaryView: View {
    let distance: Double
    let elapsedSeconds: Int
    let avgPace: Double
    let calories: Int
    let lapPaces: [RunLapPace]
    let routeCoordinates: [CLLocationCoordinate2D]
    let onSave: () -> Void
    let onDiscard: () -> Void

    @State private var mapSnapshot: UIImage?
    @State private var isGeneratingSnapshot = false
    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        ZStack {
            // 전체 화면 지도 (경로 포함)
            if routeCoordinates.count >= 2 {
                Map(position: $cameraPosition, interactionModes: []) {
                    MapPolyline(coordinates: smoothedRouteCoordinates(from: routeCoordinates))
                        .stroke(
                            LinearGradient(
                                colors: [Color.main500, Color.sub500],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                        )
                }
                .mapStyle(.standard)
                .ignoresSafeArea()
                .onAppear { fitRoute() }
            } else {
                Color(.systemGray6).ignoresSafeArea()
            }

            VStack(spacing: 0) {
                // 상단 스탯 오버레이
                statsOverlay
                    .padding(.top, 60)
                    .padding(.horizontal, 16)

                Spacer()

                // 확인 버튼 (하단)
                Button(action: onSave) {
                    Text("확인")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.main500)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - 상단 스탯

    private var statsOverlay: some View {
        VStack(spacing: 0) {
            HStack {
                Text("러닝 완료")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
                Spacer()
            }
            .padding(.bottom, 4)

            // 거리 (대형)
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(formattedDistance)
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)
                Text("km")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
                    .padding(.bottom, 6)
                Spacer()
            }

            Divider().opacity(0.3).padding(.vertical, 10)

            // 시간 / 평균 페이스 / 칼로리
            HStack(spacing: 0) {
                subStatItem(value: formattedTime, label: "시간")
                Divider().frame(height: 36).opacity(0.3)
                subStatItem(value: formattedAvgPace, label: "평균 페이스")
                Divider().frame(height: 36).opacity(0.3)
                subStatItem(value: formattedCalories, label: "칼로리", minimumScaleFactor: 0.55)
            }

            if !lapPaces.isEmpty {
                Divider().opacity(0.3).padding(.vertical, 14)

                VStack(alignment: .leading, spacing: 12) {
                    Text("평균 페이스")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)

                    ForEach(lapPaces) { lap in
                        HStack(spacing: 12) {
                            Text("\(lap.kilometer)km")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.textPrimary)

                            Spacer()

                            Text(formattedPace(lap.pace))
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.textPrimary)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func subStatItem(
        value: String,
        label: String,
        minimumScaleFactor: CGFloat = 0.8
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(minimumScaleFactor)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
    }

    // MARK: - Formatting

    private var formattedDistance: String { String(format: "%.2f", distance) }

    private var formattedTime: String {
        let h = elapsedSeconds / 3600
        let m = (elapsedSeconds % 3600) / 60
        let s = elapsedSeconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }

    private var formattedAvgPace: String {
        guard avgPace > 0 else { return "--'--\"" }
        let min = Int(avgPace)
        let sec = Int((avgPace - Double(min)) * 60)
        return String(format: "%d'%02d\"", min, sec)
    }

    private var formattedCalories: String {
        "\(calories) kcal"
    }

    private func formattedPace(_ pace: Double) -> String {
        guard pace > 0 else { return "--'--\"" }
        let min = Int(pace)
        let sec = Int((pace - Double(min)) * 60)
        return String(format: "%d'%02d\"", min, sec)
    }

    // MARK: - 경로에 맞게 카메라 맞추기

    private func fitRoute() {
        guard routeCoordinates.count >= 2 else { return }
        let lats = routeCoordinates.map(\.latitude)
        let lons = routeCoordinates.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: ((lats.min()! + lats.max()!) / 2),
            longitude: ((lons.min()! + lons.max()!) / 2)
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((lats.max()! - lats.min()!) * 1.5, 0.003),
            longitudeDelta: max((lons.max()! - lons.min()!) * 1.5, 0.003)
        )
        cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
    }

    private func smoothedRouteCoordinates(from coordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        guard coordinates.count >= 2 else { return coordinates }

        var result: [CLLocationCoordinate2D] = [coordinates[0]]

        for index in 1..<coordinates.count {
            let previous = coordinates[index - 1]
            let current = coordinates[index]
            let previousLocation = CLLocation(latitude: previous.latitude, longitude: previous.longitude)
            let currentLocation = CLLocation(latitude: current.latitude, longitude: current.longitude)
            let distance = currentLocation.distance(from: previousLocation)
            let stepCount = min(max(Int(distance / 4.0), 0), 8)

            if stepCount > 0 {
                for step in 1...stepCount {
                    let progress = Double(step) / Double(stepCount + 1)
                    result.append(
                        CLLocationCoordinate2D(
                            latitude: previous.latitude + (current.latitude - previous.latitude) * progress,
                            longitude: previous.longitude + (current.longitude - previous.longitude) * progress
                        )
                    )
                }
            }

            result.append(current)
        }

        return result
    }
}
