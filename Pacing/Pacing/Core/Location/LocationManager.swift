import CoreLocation
import Combine
import UIKit

final class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()

    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var routeCoordinates: [CLLocationCoordinate2D] = []
    @Published private(set) var recentRecordedLocations: [CLLocation] = []

    private let manager = CLLocationManager()
    private var isRecordingRoute = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 5
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = false
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        authorizationStatus = manager.authorizationStatus
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
        startUpdatingLocationIfAuthorized()
    }

    func stopTracking() {
        isRecordingRoute = false
        recentRecordedLocations = []
        startUpdatingLocationIfAuthorized()
    }

    func resetRoute() {
        isRecordingRoute = false
        routeCoordinates = []
        recentRecordedLocations = []
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
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let validLocations = locations.filter { $0.horizontalAccuracy >= 0 }
        guard !validLocations.isEmpty else { return }

        currentLocation = validLocations.last

        guard isRecordingRoute else {
            recentRecordedLocations = []
            return
        }

        let preciseLocations = validLocations.filter { $0.horizontalAccuracy < 20 }
        guard !preciseLocations.isEmpty else {
            recentRecordedLocations = []
            return
        }

        recentRecordedLocations = preciseLocations
        appendRouteCoordinates(from: preciseLocations)
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
