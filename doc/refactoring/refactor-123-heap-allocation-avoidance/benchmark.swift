import Foundation

private let inputCount = 1_000
private let repetitionsPerSample = 5
private let sampleCount = 15
private let locale = Locale(identifier: "ko_KR")
private let dates = (0..<inputCount).map {
    Date(timeIntervalSinceReferenceDate: TimeInterval($0 * 3_601))
}

private let cachedDateFormatter = makeFormatter("yyyy. M. d.")
private let cachedStartTimeFormatter = makeFormatter("a h시 m분")

private func makeFormatter(_ format: String) -> DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.dateFormat = format
    return formatter
}

@inline(never) private func before() -> [String] {
    dates.flatMap { date -> [String] in
        let dateFormatter = makeFormatter("yyyy. M. d.")
        let timeFormatter = makeFormatter("a h시 m분")
        return [dateFormatter.string(from: date), timeFormatter.string(from: date)]
    }
}

@inline(never) private func after() -> [String] {
    dates.flatMap { date in
        [cachedDateFormatter.string(from: date), cachedStartTimeFormatter.string(from: date)]
    }
}

private func median(_ values: [Double]) -> Double {
    values.sorted()[values.count / 2]
}

private func measure(_ body: () -> [String]) -> Double {
    let expected = before()
    precondition(body() == expected)

    let samples = (0..<sampleCount).map { _ -> Double in
        let start = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<repetitionsPerSample { precondition(body() == expected) }
        return Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000 / Double(repetitionsPerSample)
    }
    return median(samples)
}

let beforeMilliseconds = measure(before)
let afterMilliseconds = measure(after)
let improvement = (1 - afterMilliseconds / beforeMilliseconds) * 100

print("before_ms=\(beforeMilliseconds) after_ms=\(afterMilliseconds) improvement=\(improvement)")
