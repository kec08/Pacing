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

final class RunningViewModel: ObservableObject {
    @Published var state: RunningState = .idle
    @Published var elapsedSeconds: Int = 0
    @Published var distance: Double = 0       // km
    @Published var currentPace: Double = 0    // 분/km

    let locationManager: LocationManager

    // 주변 러너 브로드캐스트용
    var musicViewModel: RunningMusicViewModel?

    private var timer: AnyCancellable?
    private var lastLocation: CLLocation?
    private var paceBuffer: [Double] = []
    private var cancellables = Set<AnyCancellable>()

    init(locationManager: LocationManager = .shared) {
        self.locationManager = locationManager
        locationManager.startMonitoringCurrentLocation()

        locationManager.$currentLocation
            .compactMap { $0 }
            .sink { [weak self] loc in
                self?.updateDistance(with: loc)
            }
            .store(in: &cancellables)
    }

    // MARK: - Controls

    func start() {
        locationManager.requestPermission()
        locationManager.resetRoute()
        lastLocation = nil
        paceBuffer = []
        locationManager.startTracking()
        state = .running
        startTimer()
    }

    func pause() {
        state = .paused
        timer?.cancel()
        lastLocation = nil   // 재개 시 드리프트로 인한 거리/페이스 스파이크 방지
        locationManager.stopTracking()
    }

    func resume() {
        state = .running
        lastLocation = nil
        locationManager.startTracking()
        startTimer()
    }

    func stop() {
        timer?.cancel()
        locationManager.stopTracking()
        state = .finished
    }

    func reset() {
        timer?.cancel()
        locationManager.resetRoute()
        elapsedSeconds = 0
        distance = 0
        currentPace = 0
        lastLocation = nil
        paceBuffer = []
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

    // MARK: - Private

    private func startTimer() {
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.elapsedSeconds += 1
            }
    }

    private func updateDistance(with newLocation: CLLocation) {
        guard state == .running else { return }
        defer { lastLocation = newLocation }
        guard let last = lastLocation else { return }

        let deltaMeters = newLocation.distance(from: last)
        let timeDelta = newLocation.timestamp.timeIntervalSince(last.timestamp)
        guard deltaMeters > 0, timeDelta > 0 else { return }

        // GPS 스파이크 필터: 36 km/h(10 m/s) 초과는 GPS 오류로 간주하고 무시
        let speedMs = deltaMeters / timeDelta
        guard speedMs < 10.0 else { return }

        let deltaKm = deltaMeters / 1000.0
        distance += deltaKm

        // 페이스 스무딩: 최근 5개 샘플 평균
        let rawPace = (timeDelta / 60.0) / deltaKm
        paceBuffer.append(rawPace)
        if paceBuffer.count > 5 { paceBuffer.removeFirst() }
        currentPace = paceBuffer.reduce(0, +) / Double(paceBuffer.count)
    }

    func saveRecord(
        distance: Double? = nil,
        elapsedSeconds: Int? = nil,
        avgPace: Double? = nil,
        routeCoordinates: [CLLocationCoordinate2D]? = nil
    ) async {
        let savedDistance = distance ?? self.distance
        let savedElapsedSeconds = elapsedSeconds ?? self.elapsedSeconds
        let savedAveragePace = avgPace ?? self.avgPace
        let savedRouteCoordinates = routeCoordinates ?? locationManager.routeCoordinates

        guard savedElapsedSeconds >= 60 else { return }  // 1분 미만은 저장하지 않음
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let record = RunRecord(
            id: UUID().uuidString,
            startedAt: Date().addingTimeInterval(-Double(savedElapsedSeconds)),
            duration: savedElapsedSeconds,
            distance: savedDistance,
            avgPace: savedAveragePace,
            routeCoordinates: savedRouteCoordinates
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
}
