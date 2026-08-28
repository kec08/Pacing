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
        isRecordingRoute = true
        configureBackgroundLocationSupport()
        startUpdatingLocationIfAuthorized()
    }

    func stopTracking() {
        isRecordingRoute = false
        recentRecordedLocations = []
        configureBackgroundLocationSupport()
        startUpdatingLocationIfAuthorized()
    }

    func resetRoute() {
        isRecordingRoute = false
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
        // 백그라운드에서는 위치가 배치로 도착하고 정확도가 다소 흔들릴 수 있어 허용 범위를 완화한다.
        let maxHorizontalAccuracy = UIApplication.shared.applicationState == .active ? 30.0 : 65.0

        return locations.filter { location in
            location.horizontalAccuracy >= 0 &&
            location.horizontalAccuracy <= maxHorizontalAccuracy &&
            abs(location.timestamp.timeIntervalSinceNow) < 180
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

        recentRecordedLocations = recordedLocations
        self.recordedLocations.append(contentsOf: recordedLocations)
        appendRouteCoordinates(from: recordedLocations)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let clError = error as? CLError else { return }

        // 일시적인 위치 미확정 오류는 다음 업데이트를 기다린다.
        if clError.code == .locationUnknown {
            return
        }
    }

    private func appendRouteCoordinates(from locations: [CLLocation]) {
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
