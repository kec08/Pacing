import CoreMotion
import Foundation

protocol CadenceRepository: AnyObject {
    var isCadenceAvailable: Bool { get }

    func startUpdates(
        from startDate: Date,
        handler: @escaping (CadenceSample) -> Void
    )

    func stopUpdates()
}

final class CoreMotionCadenceRepository: CadenceRepository {
    private let pedometer = CMPedometer()
    private var isUpdating = false

    var isCadenceAvailable: Bool {
        CMPedometer.isCadenceAvailable()
    }

    func startUpdates(
        from startDate: Date,
        handler: @escaping (CadenceSample) -> Void
    ) {
        guard isCadenceAvailable, !isUpdating else { return }
        isUpdating = true

        pedometer.startUpdates(from: startDate) { [weak self] data, _ in
            guard let self, let data else { return }

            let sample = CadenceSample(
                timestamp: data.endDate,
                cumulativeSteps: data.numberOfSteps.intValue,
                currentCadenceStepsPerSecond: data.currentCadence?.doubleValue
            )

            DispatchQueue.main.async {
                guard self.isUpdating else { return }
                handler(sample)
            }
        }
    }

    func stopUpdates() {
        guard isUpdating else { return }
        isUpdating = false
        pedometer.stopUpdates()
    }
}
