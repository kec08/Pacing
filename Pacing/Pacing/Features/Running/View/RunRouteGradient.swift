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
        var segments: [RunRouteGradientSegment] = []
        segments.reserveCapacity(segmentCount)

        for index in 0..<segmentCount {
            let startIndex = index * lineSegmentCount / segmentCount
            let endIndex = (index + 1) * lineSegmentCount / segmentCount
            guard endIndex > startIndex else { continue }

            segments.append(RunRouteGradientSegment(
                id: index,
                coordinates: Array(coordinates[startIndex...endIndex]),
                color: color(at: Double(index) / Double(max(segmentCount - 1, 1)))
            ))
        }

        return segments
    }

    private static func color(at progress: Double) -> Color {
        let clampedProgress = min(max(progress, 0), 1)
        // 경로의 앞 65%는 Pacing 핑크를 유지하고, 마지막 구간에서 보라로 전환한다.
        let gradientProgress = min(max((clampedProgress - 0.65) / 0.35, 0), 1)
        let start = (red: 1.0, green: 0.216, blue: 0.373) // main500
        let end = (red: 0.369, green: 0.361, blue: 0.902) // sub500

        return Color(
            red: start.red + (end.red - start.red) * gradientProgress,
            green: start.green + (end.green - start.green) * gradientProgress,
            blue: start.blue + (end.blue - start.blue) * gradientProgress
        )
    }
}
