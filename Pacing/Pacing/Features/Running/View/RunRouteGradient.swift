import SwiftUI
import CoreLocation

struct RunRouteGradientSegment: Identifiable {
    let id: Int
    let coordinates: [CLLocationCoordinate2D]
    let color: Color
    /// 경로가 지도 위에서 잘 보이도록 선 아래에 까는 테두리 색. 선 색을 어둡게 한 값이다.
    let outlineColor: Color
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
                color: color(at: Double(index) / Double(max(segmentCount - 1, 1))),
                outlineColor: color(
                    at: Double(index) / Double(max(segmentCount - 1, 1)),
                    brightness: outlineBrightness
                )
            ))
        }

        return segments
    }

    /// 테두리는 선 색의 65% 밝기로 그린다.
    static let outlineBrightness = 0.65

    private static func color(at progress: Double, brightness: Double = 1) -> Color {
        let clampedProgress = min(max(progress, 0), 1)
        // 경로의 앞 65%는 Pacing 핑크를 유지하고, 마지막 구간에서 보라로 전환한다.
        let gradientProgress = min(max((clampedProgress - 0.65) / 0.35, 0), 1)
        let start = (red: 1.0, green: 0.216, blue: 0.373) // main500
        let end = (red: 0.369, green: 0.361, blue: 0.902) // sub500

        return Color(
            red: (start.red + (end.red - start.red) * gradientProgress) * brightness,
            green: (start.green + (end.green - start.green) * gradientProgress) * brightness,
            blue: (start.blue + (end.blue - start.blue) * gradientProgress) * brightness
        )
    }
}
