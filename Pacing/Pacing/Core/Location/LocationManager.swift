import CoreLocation
import Combine

final class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()

    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var routeCoordinates: [CLLocationCoordinate2D] = []

    private let manager = CLLocationManager()
    private var isRecordingRoute = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 5
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = false
        authorizationStatus = manager.authorizationStatus
        startUpdatingLocationIfAuthorized()
    }

    func requestPermission() {
        guard authorizationStatus == .notDetermined else {
            startUpdatingLocationIfAuthorized()
                                                                 }
        manager.requestAlwaysAuthorization()
    }

    func startMonitoringCurrentLocation() {
        startUpdatingLocationIfAuthorized()
        requestCurrentLocation()
    }

    func requestCurrentLocation() {
        guard authorizationStatus == .authorizedAlways ||
                authorizationStatus == .authorizedWhenInUse else { return }
        manager.requestLocation()
    }

    func startTracking() {
        isRecordingRoute = true
        startUpdatingLocationIfAuthorized()
    }

    func stopTracking() {
        isRecordingRoute = false
        startUpdatingLocationIfAuthorized()
    }

    func resetRoute() {
        isRecordingRoute = false
        routeCoordinates = []
    }

    private func startUpdatingLocationIfAuthorized() {
        guard authorizationStatus == .authorizedAlways ||
                authorizationStatus == .authorizedWhenInUse else { return }
        manager.startUpdatingLocation()
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        startUpdatingLocationIfAuthorized()
        requestCurrentLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last, loc.horizontalAccuracy >= 0 else { return }
        currentLocation = loc

        // 현재 위치 표시는 더 빠르게 반영하되, 경로 기록은 정확한 좌표만 사용한다.
        guard loc.horizontalAccuracy < 20 else { return }
        guard isRecordingRoute else { return }
        routeCoordinates.append(loc.coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let clError = error as? CLError else { return }

        // 일시적인 위치 미확정 오류는 다음 업데이트를 기다린다.
        if clError.code == .locationUnknown {
            return
        }
    }
}
