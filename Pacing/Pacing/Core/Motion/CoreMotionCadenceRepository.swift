import CoreMotion
import Foundation

protocol CadenceRepository: AnyObject {
    var isCadenceAvailable: Bool { get }

    func startUpdates(
        from startDate: Date,
        handler: @escaping (CadenceSample) -> Void
    )

    func queryData(
        from startDate: Date,
        to endDate: Date,
        completion: @escaping (CadenceSample?) -> Void
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

    func queryData(
        from startDate: Date,
        to endDate: Date,
        completion: @escaping (CadenceSample?) -> Void
    ) {
        guard isCadenceAvailable, endDate >= startDate else {
            completion(nil)
            return
        }

        pedometer.queryPedometerData(from: startDate, to: endDate) { data, _ in
            guard let data else {
                completion(nil)
                return
            }

            completion(CadenceSample(
                timestamp: data.endDate,
                cumulativeSteps: data.numberOfSteps.intValue,
                currentCadenceStepsPerSecond: data.currentCadence?.doubleValue
            ))
        }
    }
}
