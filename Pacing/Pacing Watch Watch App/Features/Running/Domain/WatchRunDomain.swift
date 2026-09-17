import Foundation

enum WatchRunState: Equatable {
    case idle
    case countdown(Int)
    case starting
    case running
    case paused
    case ending
    case ended
    case failed(WatchRunError)

    var isActive: Bool {
        switch self {
        case .countdown, .starting, .running, .paused, .ending:
            true
        case .idle, .ended, .failed:
            false
        }
    }
}

enum WatchRunError: Error, Equatable {
    case healthDataUnavailable
    case healthAuthorizationRequired
    case locationAuthorizationRequired
    case sessionUnavailable
    case sessionStartFailed
    case sessionEndFailed
    case mirroredSessionUnavailable

    var userMessage: String {
        switch self {
        case .healthDataUnavailable:
            "이 Apple Watch에서는 운동 데이터를 사용할 수 없어요."
        case .healthAuthorizationRequired:
            "건강 앱 권한을 허용한 뒤 다시 시작해 주세요."
        case .locationAuthorizationRequired:
            "정확한 거리와 페이스를 위해 위치 권한이 필요해요."
        case .sessionUnavailable:
            "운동 세션을 준비할 수 없어요."
        case .sessionStartFailed:
            "러닝을 시작하지 못했어요. 잠시 후 다시 시도해 주세요."
        case .sessionEndFailed:
            "운동을 저장하지 못했어요. 다음 러닝은 계속 시작할 수 있어요."
        case .mirroredSessionUnavailable:
            "iPhone의 러닝 세션을 Watch에 연결하지 못했어요."
        }
    }
}

struct WatchRunMetrics: Equatable {
    var elapsed: TimeInterval = 0
    var distanceMeters: Double = 0
    var currentPaceSecondsPerKilometer: Double?
    var heartRateBeatsPerMinute: Double?
    var activeEnergyKilocalories: Double?

    static let empty = WatchRunMetrics()
}

enum WatchRunDisplayMetric: CaseIterable {
    case elapsed
    case distance
    case currentPace
    case heartRate

    var title: String {
        switch self {
        case .elapsed: "시간"
        case .distance: "거리"
        case .currentPace: "현재 페이스"
        case .heartRate: "심박수"
        }
    }

    func next() -> Self {
        let metrics = Self.allCases
        guard let index = metrics.firstIndex(of: self) else { return .elapsed }
        return metrics[(index + 1) % metrics.count]
    }
}

extension WatchRunMetrics {
    var formattedElapsed: String {
        let totalSeconds = max(0, Int(elapsed.rounded(.down)))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%02d:%02d", minutes, seconds)
    }

    var formattedElapsedIncludingHours: String {
        let totalSeconds = max(0, Int(elapsed.rounded(.down)))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    var formattedDistance: String {
        String(format: "%.2f", distanceMeters / 1_000)
    }

    var formattedPace: String {
        guard let currentPaceSecondsPerKilometer, currentPaceSecondsPerKilometer > 0 else {
            return "--'--\""
        }

        let seconds = Int(currentPaceSecondsPerKilometer.rounded())
        return String(format: "%d'%02d\"", seconds / 60, seconds % 60)
    }
}
