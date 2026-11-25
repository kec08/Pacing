import CoreLocation
import WeatherKit

/// 러닝을 마친 시점의 출발 위치 날씨를 WeatherKit으로 조회한다.
/// capability 미설정·네트워크 오류 등 실패는 nil로 넘겨 기록 저장을 막지 않는다.
enum RunWeatherRepository {
    static func currentWeather(at coordinate: CLLocationCoordinate2D) async -> RunWeatherSnapshot? {
        guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let current = try? await WeatherService.shared.weather(for: location, including: .current) else {
            return nil
        }
        let celsius = current.temperature.converted(to: .celsius).value
        guard celsius.isFinite, !current.symbolName.isEmpty else { return nil }
        return RunWeatherSnapshot(temperatureCelsius: celsius, symbolName: current.symbolName)
    }
}

/// 느린 부가 조회가 기록 저장을 오래 붙잡지 않도록 제한 시간을 둔다.
enum AsyncTimeout {
    static func value<T: Sendable>(
        seconds: Double,
        operation: @escaping @Sendable () async -> T?
    ) async -> T? {
        await withTaskGroup(of: T?.self) { group in
            group.addTask { await operation() }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }
}
