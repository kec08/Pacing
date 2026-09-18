import Combine
import Foundation

@MainActor
final class WatchRunningViewModel: ObservableObject {
    @Published private(set) var state: WatchRunState = .idle
    @Published private(set) var metrics = WatchRunMetrics.empty
    @Published var displayMetric: WatchRunDisplayMetric = .averagePace
    @Published private(set) var secondaryMetrics: [WatchRunDisplayMetric] = [.distance, .heartRate]

    private var timer: AnyCancellable?
    private var countdownTask: Task<Void, Never>?
    private var startedAt: Date?
    private var elapsedBeforeCurrentSegment: TimeInterval = 0
    private let workoutRepository: HealthKitWatchWorkoutRepository
    private let locationRepository: WatchRunLocationRepository
    private var cancellables = Set<AnyCancellable>()
    /// Xcode Preview에는 HealthKit 운동 세션을 지원하는 Watch 런타임이 없으므로
    /// 화면 상태만 검증할 수 있는 안전한 타이머 경로를 사용한다.
    private let usesPreviewMetrics: Bool

    init(
        workoutRepository: HealthKitWatchWorkoutRepository? = nil,
        locationRepository: WatchRunLocationRepository? = nil,
        usesPreviewMetrics: Bool = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    ) {
        let workoutRepository = workoutRepository ?? HealthKitWatchWorkoutRepository()
        self.workoutRepository = workoutRepository
        self.locationRepository = locationRepository ?? WatchRunLocationRepository()
        self.usesPreviewMetrics = usesPreviewMetrics

        workoutRepository.$liveMetrics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] liveMetrics in
                self?.metrics.distanceMeters = liveMetrics.distanceMeters
                self?.metrics.heartRateBeatsPerMinute = liveMetrics.heartRateBeatsPerMinute
                self?.metrics.activeEnergyKilocalories = liveMetrics.activeEnergyKilocalories
            }
            .store(in: &cancellables)

        self.locationRepository.$routePoints
            .receive(on: DispatchQueue.main)
            .sink { [weak self] points in
                self?.metrics.routePoints = points
            }
            .store(in: &cancellables)
    }

    func start() {
        guard state == .idle || state == .ended || isFailure else { return }

        state = .countdown(3)
        resetMetrics()

        countdownTask?.cancel()
        countdownTask = Task { [weak self] in
            for count in stride(from: 3, through: 1, by: -1) {
                guard !Task.isCancelled, let self else { return }
                self.state = .countdown(count)
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }

            guard !Task.isCancelled, let self else { return }
            self.startWorkoutAfterCountdown()
        }
    }

    private func startWorkoutAfterCountdown() {
        state = .starting

        if usesPreviewMetrics {
            startedAt = .now
            state = .running
            startTimer()
            return
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                try await workoutRepository.start()
                startedAt = .now
                state = .running
                locationRepository.startTracking()
                startTimer()
            } catch let error as WatchRunError {
                state = .failed(error)
            } catch {
                state = .failed(.sessionStartFailed)
            }
        }
    }

    func pauseOrResume() {
        switch state {
        case .running:
            syncElapsed()
            elapsedBeforeCurrentSegment = metrics.elapsed
            startedAt = nil
            timer?.cancel()
            if !usesPreviewMetrics {
                workoutRepository.pause()
                locationRepository.pauseTracking()
            }
            state = .paused
        case .paused:
            startedAt = .now
            state = .running
            if !usesPreviewMetrics {
                workoutRepository.resume()
                locationRepository.startTracking()
            }
            startTimer()
        default:
            break
        }
    }

    func end() {
        guard state == .running || state == .paused else { return }
        state = .ending
        syncElapsed()
        timer?.cancel()
        startedAt = nil
        locationRepository.pauseTracking()

        if usesPreviewMetrics {
            state = .ended
            return
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                try await workoutRepository.end()
                state = .ended
            } catch let error as WatchRunError {
                state = .failed(error)
            } catch {
                state = .failed(.sessionEndFailed)
            }
        }
    }

    func reset() {
        countdownTask?.cancel()
        countdownTask = nil
        timer?.cancel()
        startedAt = nil
        elapsedBeforeCurrentSegment = 0
        resetMetrics()
        locationRepository.reset()
        state = .idle
        displayMetric = .averagePace
        secondaryMetrics = [.distance, .heartRate]
    }

    func selectNextDisplayMetric() {
        displayMetric = displayMetric.next()
    }

    func selectDisplayMetric(_ metric: WatchRunDisplayMetric) {
        displayMetric = metric
    }

    func selectNextSecondaryMetric(at index: Int) {
        guard secondaryMetrics.indices.contains(index) else { return }

        let otherMetrics = Set(secondaryMetrics.enumerated().compactMap { offset, metric in
            offset == index ? nil : metric
        })
        var updatedMetrics = secondaryMetrics
        updatedMetrics[index] = updatedMetrics[index].next(excluding: otherMetrics)
        secondaryMetrics = updatedMetrics
    }

    private var isFailure: Bool {
        if case .failed = state { return true }
        return false
    }

    private func startTimer() {
        timer?.cancel()
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.syncElapsed() }
    }

    private func syncElapsed() {
        guard let startedAt else { return }
        metrics.elapsed = elapsedBeforeCurrentSegment + Date.now.timeIntervalSince(startedAt)
    }

    private func resetMetrics() {
        metrics = .empty
        elapsedBeforeCurrentSegment = 0
    }
}
