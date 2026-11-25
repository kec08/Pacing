import CoreLocation
import MapKit

/// 러닝 출발 좌표를 `남양주시, 대한민국`처럼 시·구 단위 이름으로 바꾼다.
enum RunPlaceNameResolver {
    static func cityName(for coordinate: CLLocationCoordinate2D) async -> String? {
        guard CLLocationCoordinate2DIsValid(coordinate),
              let request = MKReverseGeocodingRequest(
                location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
              ),
              let mapItem = try? await request.mapItems.first
        else { return nil }

        let candidates = [
            mapItem.addressRepresentations?.cityWithContext,
            mapItem.addressRepresentations?.cityName,
            mapItem.address?.shortAddress
        ]
        return candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
}
