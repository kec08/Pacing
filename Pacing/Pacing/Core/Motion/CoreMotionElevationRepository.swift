import CoreMotion
import Foundation

protocol ElevationRepository: AnyObject {
    var isRelativeElevationAvailable: Bool { get }

    func startUpdates(handler: @escaping (ElevationSample) -> Void)
    func stopUpdates()
}

final class CoreMotionElevationRepository: ElevationRepository {
    private let altimeter = CMAltimeter()
    private var isUpdating = false
    private var segmentBaseline: Double?
    private var cumulativeOffset = 0.0
    private var lastCumulativeAltitude: Double?

    var isRelativeElevationAvailable: Bool {
        CMAltimeter.isRelativeAltitudeAvailable()
    }

    func startUpdates(handler: @escaping (ElevationSample) -> Void) {
        guard isRelativeElevationAvailable, !isUpdating else { return }

        isUpdating = true
        segmentBaseline = nil
        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, _ in
            guard let self,
                  self.isUpdating,
                  let relativeAltitude = data?.relativeAltitude.doubleValue,
                  relativeAltitude.isFinite
            else { return }

            if self.segmentBaseline == nil {
                self.segmentBaseline = relativeAltitude
                self.cumulativeOffset = self.lastCumulativeAltitude ?? 0
            }

            let altitude = self.cumulativeOffset + relativeAltitude - (self.segmentBaseline ?? relativeAltitude)
            self.lastCumulativeAltitude = altitude
            handler(ElevationSample(timestamp: Date(), altitudeMeters: altitude))
        }
    }

    func stopUpdates() {
        guard isUpdating else { return }
        isUpdating = false
        altimeter.stopRelativeAltitudeUpdates()
    }
}
