import SwiftUI
import MapKit
import CoreLocation

struct RunActivityOwner {
    let uid: String
    let nickname: String
    let profileImageBase64: String?
    let statusText: String
}

struct RunActivityDetailView: View {
    let record: RunRecord
    let owner: RunActivityOwner?

    init(record: RunRecord, owner: RunActivityOwner? = nil) {
        self.record = record
        self.owner = owner
    }

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var presentsShareTemplatePicker = false

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
        .toolbar {
            if owner == nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        presentsShareTemplatePicker = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .tint(.white)
                    .accessibilityLabel("러닝 기록 공유")
                }
            }
        }
        .sheet(isPresented: $presentsShareTemplatePicker) {
            RunRecordShareTemplatePickerView(record: record)
        }
        .onAppear(perform: fitRoute)
    }

    private var activityHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let owner {
                NavigationLink {
                    FriendProfileView(
                        friend: FriendUser(
                            id: owner.uid,
                            nickname: owner.nickname,
                            profileImageBase64: owner.profileImageBase64,
                            statusText: owner.statusText,
                            source: .friend
                        )
                    )
                } label: {
                    HStack(spacing: 10) {
                        RunActivityOwnerAvatar(owner: owner)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(owner.nickname)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color.textPrimary)
                            Text(owner.statusText)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.bottom, 14)
            }
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
                compactMetric(value: formattedCadence, label: "케이던스")
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
                    routeMap
                } else {
                    ContentUnavailableView(
                        "저장된 경로가 없어요",
                        systemImage: "map",
                        description: Text("이 기록은 위치 경로를 저장하지 않았습니다.")
                    )
                    .foregroundStyle(Color.textSecondary)
                    .frame(height: 270)
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color.backgroundPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            if record.weather != nil, record.routeCoordinates.count >= 2 {
                Link(destination: Self.weatherAttributionURL) {
                    Text("날씨 정보 제공: Apple 날씨")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textSecondary)
                }
                .accessibilityLabel("날씨 정보 제공 Apple 날씨, 법적 고지 열기")
            }
        }
    }

    private var routeMap: some View {
        Map(position: $cameraPosition, interactionModes: []) {
            ForEach(routeGradientSegments) { segment in
                MapPolyline(coordinates: segment.coordinates)
                    .stroke(
                        segment.color,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
                    )
            }

            ForEach(kilometerMarkers) { marker in
                Annotation("\(marker.kilometer) km", coordinate: marker.coordinate, anchor: .center) {
                    RouteKilometerLabel(kilometer: marker.kilometer)
                }
                .annotationTitles(.hidden)
            }

            if endpointsOverlap {
                // 출발·도착이 가까우면 지도가 한쪽 핀을 겹침으로 숨기므로 하나의 핀으로 나란히 그린다.
                Annotation("출발·도착", coordinate: record.routeCoordinates[0], anchor: .center) {
                    HStack(spacing: -4) {
                        RouteEndpointDot(color: Color.success500)
                        RouteEndpointDot(color: Color.accent500)
                    }
                }
                .annotationTitles(.hidden)
            } else {
                Annotation("출발", coordinate: record.routeCoordinates[0], anchor: .center) {
                    RouteEndpointDot(color: Color.success500)
                }
                .annotationTitles(.hidden)
                Annotation("도착", coordinate: record.routeCoordinates[record.routeCoordinates.count - 1], anchor: .center) {
                    RouteEndpointDot(color: Color.accent500)
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .allowsHitTesting(false)
        .aspectRatio(0.8, contentMode: .fit)
        .overlay(alignment: .topTrailing) {
            if let locationName = record.locationName {
                RouteMapInfoCard {
                    Text(locationName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                }
                .padding(12)
                .accessibilityLabel("러닝 위치 \(locationName)")
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if let weather = record.weather {
                RouteMapInfoCard {
                    HStack(spacing: 8) {
                        Text("\(Int(weather.temperatureCelsius.rounded()))°")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.textPrimary)
                        Image(systemName: weather.symbolName)
                            .font(.system(size: 20))
                            .symbolRenderingMode(.multicolor)
                    }
                }
                .padding(12)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("러닝 당시 기온 \(Int(weather.temperatureCelsius.rounded()))도")
            }
        }
        .accessibilityLabel("러닝 이동 경로 지도")
    }

    /// 출발·도착 핀이 화면에서 겹칠 만큼 가까운지. 경로 크기의 3% 또는 80m 중 큰 값 안이면 겹친다고 본다.
    private var endpointsOverlap: Bool {
        guard let first = record.routeCoordinates.first, let last = record.routeCoordinates.last else { return false }
        let start = CLLocation(latitude: first.latitude, longitude: first.longitude)
        let end = CLLocation(latitude: last.latitude, longitude: last.longitude)
        let routeSpanMeters = record.routeCoordinates.reduce(0.0) { farthest, coordinate in
            max(farthest, start.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)))
        }
        return start.distance(from: end) <= max(80, routeSpanMeters * 0.03)
    }

    private static let weatherAttributionURL = URL(string: "https://weatherkit.apple.com/legal-attribution.html")!

    private var kilometerMarkers: [RunRouteKilometerMarker] {
        RunRouteKilometerMarkers.markers(
            for: record.routeCoordinates,
            recordedDistanceKilometers: record.distance
        )
    }

    private var splitSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("구간")
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

                splitTable
            }
        }
    }

    private var splitTable: some View {
        let laps = displayLapPaces
        let validPaces = laps.map(\.pace).filter { $0.isFinite && $0 > 0 }
        let fastest = validPaces.min() ?? 0
        let slowest = validPaces.max() ?? 0

        return VStack(spacing: 6) {
            HStack(spacing: 12) {
                Text("Km")
                    .frame(width: Self.kilometerColumnWidth, alignment: .leading)
                Text("평균 페이스")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("심박수")
                    .frame(width: Self.heartRateColumnWidth, alignment: .trailing)
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.textSecondary)
            .padding(.bottom, 6)
            .accessibilityHidden(true)

            ForEach(laps) { lap in
                splitRow(
                    lap,
                    barFraction: RunSplitBarScale.widthFraction(pace: lap.pace, fastest: fastest, slowest: slowest)
                )
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(Color.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private static let kilometerColumnWidth: CGFloat = 32
    private static let heartRateColumnWidth: CGFloat = 52

    private var displayLapPaces: [RunLapPace] {
        if !record.lapPaces.isEmpty { return record.lapPaces }

        let completedKilometers = Int(record.distance.rounded(.down))
        guard completedKilometers > 0, record.isPaceValid else { return [] }

        return (1...completedKilometers).map {
            RunLapPace(kilometer: $0, pace: record.displayPace)
        }
    }

    private var routeGradientSegments: [RunRouteGradientSegment] {
        RunRouteGradient.segments(from: record.routeCoordinates)
    }

    private func splitRow(_ lap: RunLapPace, barFraction: Double) -> some View {
        HStack(spacing: 12) {
            Text("\(lap.kilometer)")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.textPrimary)
                .frame(width: Self.kilometerColumnWidth, alignment: .leading)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.gray100)
                        .frame(width: proxy.size.width * barFraction)
                    Text(formattedPace(lap.pace))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.textPrimary)
                        .padding(.leading, 12)
                }
                .frame(maxHeight: .infinity)
            }
            .frame(height: 40)

            Text(formattedLapHeartRate(lap.averageHeartRate))
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(lap.averageHeartRate == nil ? Color.textSecondary : Color.textPrimary)
                .frame(width: Self.heartRateColumnWidth, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(lap.kilometer) 킬로미터, 평균 페이스 \(formattedPace(lap.pace)), 심박수 \(lap.averageHeartRate.map { "\(Int($0.rounded()))" } ?? "기록 없음")"
        )
    }

    private func formattedLapHeartRate(_ value: Double?) -> String {
        guard let value, value.isFinite, value > 0 else { return "--" }
        return "\(Int(value.rounded()))"
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

    private var formattedCadence: String {
        guard let value = record.averageCadence, value.isFinite, value > 0 else { return "--" }
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
            // 지도 오른쪽 위·아래 정보 카드에 경로가 가리지 않도록 여백을 넉넉히 둔다.
            paddingMultiplier: 1.6,
            minimumDelta: 0.003
        ) else { return }
        cameraPosition = .region(region)
    }
}

private struct RunActivityOwnerAvatar: View {
    let owner: RunActivityOwner

    var body: some View {
        Group {
            if let image = decodedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(Color.main200.opacity(0.8))
                    Text(owner.nickname.prefix(1).isEmpty ? "러" : String(owner.nickname.prefix(1)))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.main500)
                }
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(Circle())
        .overlay { Circle().stroke(Color.surfaceBorder, lineWidth: 1) }
    }

    private var decodedImage: UIImage? {
        guard let encoded = owner.profileImageBase64,
              let data = Data(base64Encoded: encoded) else { return nil }
        return UIImage(data: data)
    }
}

/// 구간 표 페이스 막대 길이. 빠른 구간일수록 길다.
enum RunSplitBarScale {
    static let minimumFraction = 0.35

    static func widthFraction(pace: Double, fastest: Double, slowest: Double) -> Double {
        guard pace.isFinite, pace > 0, fastest > 0, slowest >= fastest else { return minimumFraction }
        let range = slowest - fastest
        guard range > 0.001 else { return 1 }
        let speedRatio = (slowest - min(max(pace, fastest), slowest)) / range
        return minimumFraction + (1 - minimumFraction) * speedRatio
    }
}

private struct RouteEndpointDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 16, height: 16)
            .overlay { Circle().stroke(Color.white, lineWidth: 3) }
            .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
    }
}

private struct RouteKilometerLabel: View {
    let kilometer: Int

    var body: some View {
        Text("\(kilometer) km")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.black)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.white))
            .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
    }
}

private struct RouteMapInfoCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.backgroundPrimary.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 2)
    }
}
