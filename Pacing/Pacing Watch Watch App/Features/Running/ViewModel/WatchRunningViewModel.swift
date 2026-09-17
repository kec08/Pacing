import Combine
import Foundation

@MainActor
final class WatchRunningViewModel: ObservableObject {
    @Published private(set) var state: WatchRunState = .idle
    @Published private(set) var metrics = WatchRunMetrics.empty
    @Published var displayMetric: WatchRunDisplayMetric = .elapsed
    @Published var isEndConfirmationPresented = false

    private var timer: AnyCancellable?
    private var startedAt: Date?
    private var elapsedBeforeCurrentSegment: TimeInterval = 0
    private let workoutRepository: HealthKitWatchWorkoutRepository
    private var cancellables = Set<AnyCancellable>()

    init(workoutRepository: HealthKitWatchWorkoutRepository? = nil) {
        let workoutRepository = workoutRepository ?? HealthKitWatchWorkoutRepository()
        self.workoutRepository = workoutRepository

        workoutRepository.$liveMetrics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] liveMetrics in
                self?.metrics.distanceMeters = liveMetrics.distanceMeters
                self?.metrics.heartRateBeatsPerMinute = liveMetrics.heartRateBeatsPerMinute
                self?.metrics.activeEnergyKilocalories = liveMetrics.activeEnergyKilocalories
            }
            .store(in: &cancellables)
    }

    func start() {
        guard state == .idle || state == .ended || isFailure else { return }

        state = .starting
        resetMetrics()

        Task { [weak self] in
            guard let self else { return }
            do {
                try await workoutRepository.start()
                startedAt = .now
                state = .running
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
            workoutRepository.pause()
            state = .paused
        case .paused:
            startedAt = .now
            state = .running
            workoutRepository.resume()
            startTimer()
        default:
            break
        }
    }

    func requestEnd() {
        guard state == .running || state == .paused else { return }
        isEndConfirmationPresented = true
    }

    func end() {
        guard state == .running || state == .paused else { return }
        state = .ending
        syncElapsed()
        timer?.cancel()
        startedAt = nil

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
        timer?.cancel()
        startedAt = nil
        elapsedBeforeCurrentSegment = 0
        resetMetrics()
        state = .idle
        displayMetric = .elapsed
    }

    func selectNextDisplayMetric() {
        displayMetric = displayMetric.next()
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
