import CoreLocation
import Combine
import UIKit

enum LocationBackgroundConfiguration {
    nonisolated static func supportsLocationMode(_ value: Any?) -> Bool {
        let normalizedModes: [String]

        switch value {
        case let values as [String]:
            normalizedModes = values
        case let values as [Any]:
            normalizedModes = values.compactMap { $0 as? String }
        case let mode as String:
            normalizedModes = mode.split(whereSeparator: { $0.isWhitespace || $0 == "," }).map(String.init)
        default:
            normalizedModes = []
        }

        return normalizedModes.contains { $0.caseInsensitiveCompare("location") == .orderedSame }
    }

    nonisolated static func shouldEnableBackgroundUpdates(
        supportsLocationMode: Bool,
        authorizationStatus: CLAuthorizationStatus,
        isRecordingRoute: Bool
    ) -> Bool {
        supportsLocationMode && authorizationStatus == .authorizedAlways && isRecordingRoute
    }
}

final class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()

    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var routeCoordinates: [CLLocationCoordinate2D] = []
    @Published private(set) var recentRecordedLocations: [CLLocation] = []
    @Published private(set) var recordedLocations: [CLLocation] = []

    private let manager = CLLocationManager()
    private var isRecordingRoute = false
    private var recordingStartedAt: Date?
    private var notificationObservers: [NSObjectProtocol] = []

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 5
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = false
        authorizationStatus = manager.authorizationStatus
        observeApplicationLifecycle()
        configureBackgroundLocationSupport()
        startUpdatingLocationIfAuthorized()
    }

    
    func requestPermission() {
        if authorizationStatus == .authorizedWhenInUse {
            manager.requestAlwaysAuthorization()
            startUpdatingLocationIfAuthorized()
            return
        }

        guard authorizationStatus == .notDetermined else {
            startUpdatingLocationIfAuthorized()
            return
        }
        manager.requestAlwaysAuthorization()
    }

    var hasAlwaysAuthorization: Bool {
        authorizationStatus == .authorizedAlways
    }

    func startMonitoringCurrentLocation() {
        startUpdatingLocationIfAuthorized()
    }

    func requestCurrentLocation() {
        guard authorizationStatus == .authorizedAlways ||
                authorizationStatus == .authorizedWhenInUse else { return }
        guard UIApplication.shared.applicationState == .active else { return }
        manager.requestLocation()
    }

    func startTracking() {
        recordingStartedAt = .now
        isRecordingRoute = true
        configureBackgroundLocationSupport()
        startUpdatingLocationIfAuthorized()
    }

    func stopTracking() {
        isRecordingRoute = false
        recordingStartedAt = nil
        recentRecordedLocations = []
        configureBackgroundLocationSupport()
        startUpdatingLocationIfAuthorized()
    }

    func resetRoute() {
        isRecordingRoute = false
        recordingStartedAt = nil
        routeCoordinates = []
        recentRecordedLocations = []
        recordedLocations = []
        configureBackgroundLocationSupport()
    }

    private func startUpdatingLocationIfAuthorized() {
        configureBackgroundLocationSupport()
        guard authorizationStatus == .authorizedAlways ||
                authorizationStatus == .authorizedWhenInUse else { return }
        manager.startUpdatingLocation()
    }

    private func observeApplicationLifecycle() {
        let center = NotificationCenter.default

        notificationObservers.append(
            center.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handleApplicationStateChange()
            }
        )

        notificationObservers.append(
            center.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handleApplicationStateChange()
            }
        )
    }

    private func handleApplicationStateChange() {
        configureBackgroundLocationSupport()

        guard isRecordingRoute else { return }
        startUpdatingLocationIfAuthorized()
    }

    private func configureBackgroundLocationSupport() {
        let backgroundModes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes")
        let supportsBackgroundLocation = LocationBackgroundConfiguration.supportsLocationMode(backgroundModes)
        let canStayUpInBackground = LocationBackgroundConfiguration.shouldEnableBackgroundUpdates(
            supportsLocationMode: supportsBackgroundLocation,
            authorizationStatus: authorizationStatus,
            isRecordingRoute: isRecordingRoute
        )

        manager.allowsBackgroundLocationUpdates = canStayUpInBackground
        manager.showsBackgroundLocationIndicator = canStayUpInBackground && isRecordingRoute
    }

    private func filteredRouteLocations(from locations: [CLLocation]) -> [CLLocation] {
        return locations.filter { location in
            // 화면 복귀 후 전달된 백그라운드 배치도 측정 시점에 맞는 정확도로 평가한다.
            let isLiveForeground = UIApplication.shared.applicationState == .active &&
                location.timestamp.timeIntervalSinceNow > -5
            let maxHorizontalAccuracy = isLiveForeground ? 30.0 : 65.0
            return location.horizontalAccuracy >= 0 &&
            location.horizontalAccuracy <= maxHorizontalAccuracy &&
            location.timestamp >= (recordingStartedAt ?? .distantPast).addingTimeInterval(-15) &&
            location.timestamp.timeIntervalSinceNow <= 10
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        startUpdatingLocationIfAuthorized()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let validLocations = locations.filter { $0.horizontalAccuracy >= 0 }
        guard !validLocations.isEmpty else { return }

        currentLocation = validLocations.last

        guard isRecordingRoute else {
            recentRecordedLocations = []
            return
        }

        let recordedLocations = filteredRouteLocations(from: validLocations)
        guard !recordedLocations.isEmpty else {
            recentRecordedLocations = []
            return
        }

        self.recordedLocations.append(contentsOf: recordedLocations)
        recentRecordedLocations = recordedLocations
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let clError = error as? CLError else {
            NSLog("[Pacing] 위치 측정 실패: %@", error.localizedDescription)
            return
        }

        // 일시적인 위치 미확정 오류는 다음 업데이트를 기다린다.
        if clError.code == .locationUnknown {
            return
        }
        NSLog("[Pacing] 위치 측정 실패: code=%ld recording=%d background=%d",
              clError.code.rawValue, isRecordingRoute ? 1 : 0,
              manager.allowsBackgroundLocationUpdates ? 1 : 0)
    }

    func appendAcceptedRouteSegment(from locations: [CLLocation]) {
        for location in locations {
            let coordinate = location.coordinate

            if let lastCoordinate = routeCoordinates.last {
                let lastLocation = CLLocation(
                    latitude: lastCoordinate.latitude,
                    longitude: lastCoordinate.longitude
                )
                let distance = location.distance(from: lastLocation)

                // 동일 좌표 또는 노이즈 수준 좌표는 중복 기록하지 않는다.
                guard distance >= 1 else { continue }
            }

            routeCoordinates.append(coordinate)
        }
    }
}
