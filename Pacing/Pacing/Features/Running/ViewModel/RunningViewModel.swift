import SwiftUI
import Combine
import CoreLocation
import FirebaseAuth
import MusicKit
import UIKit

enum RunningState {
    case idle
    case running
    case paused
    case finished
}

enum RunningPacePolicy {
    /// 정지 상태의 GPS 흔들림으로 페이스가 표시되는 것을 막기 위한 최소 유효 이동 거리입니다.
    static let minimumDistanceForPaceKilometers = 0.02
    private static let minimumRunningSpeedMetersPerSecond = 0.8
    private static let maximumRunningSpeedMetersPerSecond = 10.0

    static func isValidRunningSegment(
        distanceMeters: CLLocationDistance,
        timeInterval: TimeInterval,
        previousHorizontalAccuracy: CLLocationAccuracy,
        currentHorizontalAccuracy: CLLocationAccuracy
    ) -> Bool {
        guard distanceMeters > 0, timeInterval > 0 else { return false }

        let speed = distanceMeters / timeInterval
        guard speed >= minimumRunningSpeedMetersPerSecond,
              speed < maximumRunningSpeedMetersPerSecond
        else { return false }

        // 정확도가 낮을수록 조금 더 큰 이동을 요구하되, 정상적인 러닝 위치 업데이트는 놓치지 않는다.
        let accuracy = max(previousHorizontalAccuracy, currentHorizontalAccuracy)
        let minimumDistance = max(3.0, min(12.0, accuracy * 0.5))
        return distanceMeters >= minimumDistance
    }

    static func canDisplayPace(distanceKilometers: Double, elapsedSeconds: Int) -> Bool {
        distanceKilometers >= minimumDistanceForPaceKilometers && elapsedSeconds > 0
    }
}

final class RunningViewModel: ObservableObject {
    @Published var state: RunningState = .idle
    @Published var elapsedSeconds: Int = 0
    @Published var distance: Double = 0       // km
    @Published var currentPace: Double = 0    // 분/km, 1km 랩 기준 표시
    @Published private(set) var completedLapPaces: [RunLapPace] = []
    @Published private(set) var elevationGainMeters: Double?
    @Published private(set) var averageHeartRate: Double?

    let locationManager: LocationManager

    // 주변 러너 브로드캐스트용
    var musicViewModel: RunningMusicViewModel?

    private var timer: AnyCancellable?
    private var lastLocation: CLLocation?
    private var cancellables = Set<AnyCancellable>()
    private var nextLapDistanceMark: Double = 1.0
    private var lapStartDistance: Double = 0
    private var lapStartElapsedSeconds: Int = 0
    private var lastCompletedLapPace: Double = 0
    private var runningStartedAt: Date?
    private var healthRunStartedAt: Date?
    private var accumulatedElapsedSecondsBeforeResume: Int = 0
    private let heartRateRepository: HeartRateRepository
    private var healthAuthorizationTask: Task<Bool, Never>?

    init(
        locationManager: LocationManager = .shared,
        heartRateRepository: HeartRateRepository = HealthKitHeartRateRepository()
    ) {
        self.locationManager = locationManager
        self.heartRateRepository = heartRateRepository
        locationManager.startMonitoringCurrentLocation()

        locationManager.$recentRecordedLocations
            .sink { [weak self] locations in
                self?.updateDistance(with: locations)
            }
            .store(in: &cancellables)
    }

    // MARK: - Controls

    @discardableResult
    func start() -> Bool {
        guard locationManager.hasAlwaysAuthorization else {
            return false
        }

        locationManager.resetRoute()
        elapsedSeconds = 0
        distance = 0
        currentPace = 0
        lastLocation = nil
        resetLapState()
        accumulatedElapsedSecondsBeforeResume = 0
        let startedAt = Date()
        runningStartedAt = startedAt
        healthRunStartedAt = startedAt
        elevationGainMeters = nil
        averageHeartRate = nil
        healthAuthorizationTask = Task { await heartRateRepository.requestReadAuthorization() }
        locationManager.startTracking()
        state = .running
        startTimer()
        return true
    }

    func pause() {
        syncElapsedSeconds()
        accumulatedElapsedSecondsBeforeResume = elapsedSeconds
        runningStartedAt = nil
        state = .paused
        timer?.cancel()
        lastLocation = nil   // 재개 시 드리프트로 인한 거리/페이스 스파이크 방지
        locationManager.stopTracking()
    }

    func resume() {
        runningStartedAt = Date()
        state = .running
        lastLocation = nil
        locationManager.startTracking()
        startTimer()
    }

    func stop() async {
        syncElapsedSeconds()
        completePendingLapsIfNeeded()
        let endedAt = Date()
        let healthStartedAt = healthRunStartedAt
        accumulatedElapsedSecondsBeforeResume = elapsedSeconds
        runningStartedAt = nil
        timer?.cancel()
        locationManager.stopTracking()
        state = .finished

        elevationGainMeters = RunMetricsCalculator.elevationGain(
            from: locationManager.recordedLocations
        )
        if let healthStartedAt {
            _ = await healthAuthorizationTask?.value
            averageHeartRate = await heartRateRepository.averageHeartRate(
                from: healthStartedAt,
                to: endedAt
            )
        }
    }

    func reset() {
        timer?.cancel()
        locationManager.resetRoute()
        elapsedSeconds = 0
        distance = 0
        currentPace = 0
        lastLocation = nil
        resetLapState()
        accumulatedElapsedSecondsBeforeResume = 0
        runningStartedAt = nil
        healthRunStartedAt = nil
        healthAuthorizationTask = nil
        elevationGainMeters = nil
        averageHeartRate = nil
        state = .idle
    }

    // MARK: - Formatting

    var formattedTime: String {
        let h = elapsedSeconds / 3600
        let m = (elapsedSeconds % 3600) / 60
        let s = elapsedSeconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }

    var formattedDistance: String {
        String(format: "%.2f", distance)
    }

    var formattedPace: String {
        guard currentPace > 0 else { return "--'--\"" }
        let min = Int(currentPace)
        let sec = Int((currentPace - Double(min)) * 60)
        return String(format: "%d'%02d\"", min, sec)
    }

    var avgPace: Double {
        guard distance > 0 else { return 0 }
        return Double(elapsedSeconds) / 60.0 / distance
    }

    var formattedAvgPace: String {
        guard avgPace > 0 else { return "--'--\"" }
        let min = Int(avgPace)
        let sec = Int((avgPace - Double(min)) * 60)
        return String(format: "%d'%02d\"", min, sec)
    }

    var estimatedCalories: Int {
        let storedWeight = UserDefaults.standard.integer(forKey: "weight")
        let weight = storedWeight > 0 ? Double(storedWeight) : 60.0
        return Int((weight * distance * 1.036).rounded())
    }

    var formattedCalories: String {
        "\(estimatedCalories)"
    }

    var formattedElevationGain: String {
        guard let elevationGainMeters, elevationGainMeters.isFinite else {
            return state == .running || state == .paused ? "0m" : "--"
        }
        return "\(Int(elevationGainMeters.rounded()))m"
    }

    // MARK: - Private

    private func startTimer() {
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.syncElapsedSeconds()
                self?.updateDisplayedPace()
            }
    }

    private func updateDistance(with locations: [CLLocation]) {
        guard state == .running else { return }
        guard !locations.isEmpty else { return }

        var hasDistanceChanged = false

        for location in locations {
            syncElapsedSeconds(referenceDate: location.timestamp)

            guard let last = lastLocation else {
                lastLocation = location
                continue
            }

            defer { lastLocation = location }

            let deltaMeters = location.distance(from: last)
            let timeDelta = location.timestamp.timeIntervalSince(last.timestamp)
            guard deltaMeters > 0, timeDelta > 0 else { continue }

            guard RunningPacePolicy.isValidRunningSegment(
                distanceMeters: deltaMeters,
                timeInterval: timeDelta,
                previousHorizontalAccuracy: last.horizontalAccuracy,
                currentHorizontalAccuracy: location.horizontalAccuracy
            ) else { continue }

            let deltaKm = deltaMeters / 1000.0
            distance += deltaKm
            hasDistanceChanged = true
        }

        if hasDistanceChanged {
            updateDisplayedPace()
        }

        elevationGainMeters = RunMetricsCalculator.elevationGain(
            from: locationManager.recordedLocations
        ) ?? 0
    }

    func saveRecord(
        distance: Double? = nil,
        elapsedSeconds: Int? = nil,
        avgPace: Double? = nil,
        routeCoordinates: [CLLocationCoordinate2D]? = nil,
        lapPaces: [RunLapPace]? = nil,
        elevationGainMeters: Double? = nil,
        averageHeartRate: Double? = nil
    ) async {
        let savedDistance = distance ?? self.distance
        let savedElapsedSeconds = elapsedSeconds ?? self.elapsedSeconds
        let rawAveragePace = avgPace ?? self.avgPace
        let savedAveragePace = RunRecord(
            id: "validation",
            startedAt: Date(),
            duration: savedElapsedSeconds,
            distance: savedDistance,
            avgPace: rawAveragePace,
            routeCoordinates: [],
            lapPaces: []
        ).displayPace
        let savedRouteCoordinates = routeCoordinates ?? locationManager.routeCoordinates
        let savedLapPaces = savedAveragePace > 0 ? (lapPaces ?? completedLapPaces) : []

        guard savedElapsedSeconds >= 60 else { return }  // 1분 미만은 저장하지 않음
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let record = RunRecord(
            id: UUID().uuidString,
            startedAt: Date().addingTimeInterval(-Double(savedElapsedSeconds)),
            duration: savedElapsedSeconds,
            distance: savedDistance,
            avgPace: savedAveragePace,
            routeCoordinates: savedRouteCoordinates,
            lapPaces: savedLapPaces,
            elevationGainMeters: elevationGainMeters ?? self.elevationGainMeters,
            averageHeartRate: averageHeartRate ?? self.averageHeartRate
        )
        try? await FirestoreService.shared.saveRunRecord(uid: uid, record: record)

        if let song = musicViewModel?.currentSongSnapshot() {
            try? await FirestoreService.shared.saveRecentSong(
                uid: uid,
                title: song.title,
                artistName: song.artistName,
                songStoreID: song.songStoreID,
                artworkURL: song.artworkURL,
                artworkData: encodedArtworkData(from: song.artwork)
            )
        }
    }

    private func encodedArtworkData(from image: UIImage?) -> String? {
        guard let image else { return nil }
        let targetSize = CGSize(width: 160, height: 160)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: 0.65)?.base64EncodedString()
    }

    private func resetLapState() {
        nextLapDistanceMark = 1.0
        lapStartDistance = 0
        lapStartElapsedSeconds = 0
        lastCompletedLapPace = 0
        completedLapPaces = []
    }

    private func updateDisplayedPace() {
        guard RunningPacePolicy.canDisplayPace(
            distanceKilometers: distance,
            elapsedSeconds: elapsedSeconds
        ) else {
            currentPace = 0
            return
        }

        completePendingLapsIfNeeded()

        if lastCompletedLapPace > 0 {
            currentPace = lastCompletedLapPace
        } else {
            currentPace = avgPace
        }
    }

    private func syncElapsedSeconds(referenceDate: Date = Date()) {
        guard let runningStartedAt else {
            elapsedSeconds = max(accumulatedElapsedSecondsBeforeResume, 0)
            return
        }

        let runningSeconds = max(Int(referenceDate.timeIntervalSince(runningStartedAt)), 0)
        elapsedSeconds = accumulatedElapsedSecondsBeforeResume + runningSeconds
    }

    private func completePendingLapsIfNeeded() {
        while distance >= nextLapDistanceMark {
            let lapDistance = nextLapDistanceMark - lapStartDistance
            let lapElapsedSeconds = elapsedSeconds - lapStartElapsedSeconds

            if lapDistance > 0, lapElapsedSeconds > 0 {
                let lapPace = Double(lapElapsedSeconds) / 60.0 / lapDistance
                lastCompletedLapPace = lapPace
                completedLapPaces.append(
                    RunLapPace(
                        kilometer: Int(nextLapDistanceMark.rounded(.down)),
                        pace: lapPace
                    )
                )
            }

            lapStartDistance = nextLapDistanceMark
            lapStartElapsedSeconds = elapsedSeconds
            nextLapDistanceMark += 1.0
        }
    }
}
