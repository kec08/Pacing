import CoreLocation
import Foundation
import Combine

/// Watch 단독 러닝 중 경로 요약에 필요한 위치 샘플만 수집합니다.
@MainActor
final class WatchRunLocationRepository: NSObject, ObservableObject {
    @Published private(set) var routePoints: [WatchRunRoutePoint] = []

    private let locationManager = CLLocationManager()
    private var locations: [CLLocation] = []

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.activityType = .fitness
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 8
    }

    func startTracking() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.startUpdatingLocation()
        default:
            break
        }
    }

    func pauseTracking() {
        locationManager.stopUpdatingLocation()
    }

    func reset() {
        pauseTracking()
        locations = []
        routePoints = []
    }

    private func updateRoutePoints() {
        guard locations.count > 1 else {
            routePoints = []
            return
        }

        let latitudes = locations.map(\.coordinate.latitude)
        let longitudes = locations.map(\.coordinate.longitude)
        guard let minLatitude = latitudes.min(), let maxLatitude = latitudes.max(),
              let minLongitude = longitudes.min(), let maxLongitude = longitudes.max()
        else { return }

        let latitudeSpan = max(maxLatitude - minLatitude, 0.000_01)
        let longitudeSpan = max(maxLongitude - minLongitude, 0.000_01)
        routePoints = locations.map { location in
            WatchRunRoutePoint(
                x: (location.coordinate.longitude - minLongitude) / longitudeSpan,
                y: 1 - (location.coordinate.latitude - minLatitude) / latitudeSpan
            )
        }
    }
}

extension WatchRunLocationRepository: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            guard manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse else {
                return
            }
            self?.locationManager.startUpdatingLocation()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let validLocations = locations.filter { location in
            location.horizontalAccuracy >= 0 && location.horizontalAccuracy <= 65
        }
        guard !validLocations.isEmpty else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.locations.append(contentsOf: validLocations)
            self.updateRoutePoints()
        }
    }
}
