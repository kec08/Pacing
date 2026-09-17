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

    func start() {
        guard state == .idle || state == .ended || isFailure else { return }

        state = .starting
        resetMetrics()
        startedAt = .now
        state = .running
        startTimer()
    }

    func pauseOrResume() {
        switch state {
        case .running:
            syncElapsed()
            elapsedBeforeCurrentSegment = metrics.elapsed
            startedAt = nil
            timer?.cancel()
            state = .paused
        case .paused:
            startedAt = .now
            state = .running
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
        state = .ended
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
