import SwiftUI
import CoreLocation

struct RunRouteGradientSegment: Identifiable {
    let id: Int
    let coordinates: [CLLocationCoordinate2D]
    let color: Color
}

enum RunRouteGradient {
    static func segments(
        from coordinates: [CLLocationCoordinate2D],
        maximumSegmentCount: Int = 28
    ) -> [RunRouteGradientSegment] {
        let lineSegmentCount = coordinates.count - 1
        guard lineSegmentCount > 0 else { return [] }

        let segmentCount = min(lineSegmentCount, maximumSegmentCount)
        return (0..<segmentCount).compactMap { index in
            let startIndex = index * lineSegmentCount / segmentCount
            let endIndex = (index + 1) * lineSegmentCount / segmentCount
            guard endIndex > startIndex else { return nil }

            return RunRouteGradientSegment(
                id: index,
                coordinates: Array(coordinates[startIndex...endIndex]),
                color: color(at: Double(index) / Double(max(segmentCount - 1, 1)))
            )
        }
    }

    private static func color(at progress: Double) -> Color {
        let clampedProgress = min(max(progress, 0), 1)
        let start = (red: 1.0, green: 0.216, blue: 0.373) // main500
        let end = (red: 0.369, green: 0.361, blue: 0.902) // sub500

        return Color(
            red: start.red + (end.red - start.red) * clampedProgress,
            green: start.green + (end.green - start.green) * clampedProgress,
            blue: start.blue + (end.blue - start.blue) * clampedProgress
        )
    }
}
