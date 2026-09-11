import CoreLocation
import MapKit

enum RunRouteBounds {
    static func region(
        for coordinates: [CLLocationCoordinate2D],
        paddingMultiplier: CLLocationDegrees,
        minimumDelta: CLLocationDegrees
    ) -> MKCoordinateRegion? {
        guard let first = coordinates.first else { return nil }

        var minLatitude = first.latitude
        var maxLatitude = first.latitude
        var minLongitude = first.longitude
        var maxLongitude = first.longitude

        for coordinate in coordinates.dropFirst() {
            minLatitude = min(minLatitude, coordinate.latitude)
            maxLatitude = max(maxLatitude, coordinate.latitude)
            minLongitude = min(minLongitude, coordinate.longitude)
            maxLongitude = max(maxLongitude, coordinate.longitude)
        }

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (minLatitude + maxLatitude) / 2,
                longitude: (minLongitude + maxLongitude) / 2
            ),
            span: MKCoordinateSpan(
                latitudeDelta: max((maxLatitude - minLatitude) * paddingMultiplier, minimumDelta),
                longitudeDelta: max((maxLongitude - minLongitude) * paddingMultiplier, minimumDelta)
            )
        )
    }
}
