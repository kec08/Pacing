import SwiftUI
import MapKit
import CoreLocation

struct RunRouteThumbnailView: View {
    let coordinates: [CLLocationCoordinate2D]

    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        Group {
            if coordinates.count >= 2 {
                Map(position: $cameraPosition, interactionModes: []) {
                    MapPolyline(coordinates: coordinates)
                        .stroke(
                            Color.main500,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                        )
                }
                .mapStyle(.standard)
                .allowsHitTesting(false)
                .onAppear { cameraPosition = .region(routeRegion) }
                .accessibilityLabel("러닝 경로 미리보기")
            } else {
                Image(systemName: "map")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.gray400)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.gray100)
                    .accessibilityLabel("저장된 경로 없음")
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var routeRegion: MKCoordinateRegion {
        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)
        guard let minLatitude = latitudes.min(), let maxLatitude = latitudes.max(),
              let minLongitude = longitudes.min(), let maxLongitude = longitudes.max() else {
            return MKCoordinateRegion()
        }

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (minLatitude + maxLatitude) / 2,
                longitude: (minLongitude + maxLongitude) / 2
            ),
            span: MKCoordinateSpan(
                latitudeDelta: max((maxLatitude - minLatitude) * 1.6, 0.002),
                longitudeDelta: max((maxLongitude - minLongitude) * 1.6, 0.002)
            )
        )
    }
}
