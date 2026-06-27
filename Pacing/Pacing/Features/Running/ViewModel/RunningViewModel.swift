import SwiftUI
import Combine
import CoreLocation
import FirebaseAuth

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

    let locationManager = LocationManager()

    // 주변 러너 브로드캐스트용
    var musicViewModel: RunningMusicViewModel?

    private var timer: AnyCancellable?
    private var lastLocation: CLLocation?
    private var cancellables = Set<AnyCancellable>()

    init() {
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
        locationManager.startTracking()
        state = .running
        startTimer()
        startBroadcast()
    }

    func pause() {
        state = .paused
        timer?.cancel()
        locationManager.stopTracking()
    }

    func resume() {
        state = .running
        locationManager.startTracking()
        startTimer()
    }

    func stop() {
        timer?.cancel()
        locationManager.stopTracking()
        state = .finished
        stopBroadcast()
    }

    func reset() {
        timer?.cancel()
        locationManager.resetRoute()
        elapsedSeconds = 0
        distance = 0
        currentPace = 0
        lastLocation = nil
        state = .idle
    }

    // MARK: - 브로드캐스트
    private func startBroadcast() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let nickname = UserDefaults.standard.string(forKey: "nickname") ?? "러너"
        RealtimeDBService.shared.startBroadcast(uid: uid, nickname: nickname) { [weak self] in
            self?.locationManager.currentLocation?.coordinate
        } songProvider: { [weak self] in
            let title = self?.musicViewModel?.currentSong?.title ?? ""
            let artist = self?.musicViewModel?.currentSong?.artistName ?? ""
            return (title, artist)
        }
    }

    private func stopBroadcast() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        RealtimeDBService.shared.stopBroadcast(uid: uid)
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
        let delta = newLocation.distance(from: last) / 1000.0
        guard delta > 0 else { return }
        distance += delta
        // 페이스: 최근 이동 거리 기반 순간 페이스
        let timeDelta = newLocation.timestamp.timeIntervalSince(last.timestamp)
        if timeDelta > 0 {
            currentPace = (timeDelta / 60.0) / delta
        }
    }

    func saveRecord() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let record = RunRecord(
            id: UUID().uuidString,
            startedAt: Date().addingTimeInterval(-Double(elapsedSeconds)),
            duration: elapsedSeconds,
            distance: distance,
            avgPace: avgPace,
            routeCoordinates: locationManager.routeCoordinates
        )
        try? await FirestoreService.shared.saveRunRecord(uid: uid, record: record)
    }
}
