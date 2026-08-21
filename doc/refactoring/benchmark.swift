import Foundation

struct Coordinate {
    var latitude: Double
    let longitude: Double
}

struct RunSample {
    var distance: Double
    let duration: Int
    let valid: Bool
}

struct BenchmarkResult {
    let milliseconds: Double
    let checksum: Double
}

let sampleCount = 100_000
let repeatCount = 30
let seed = UInt64(Date().timeIntervalSince1970 * 1_000_000)
let coordinates = (0..<sampleCount).map {
    let value = Double(($0 * 31) ^ Int(seed & 0xffff))
    return Coordinate(latitude: 37.0 + value * 0.00000001, longitude: 127.0 + value * 0.00000001)
}
let records = (0..<sampleCount).map {
    let value = ($0 * 17 + Int(seed & 0xff)) % 1000
    return RunSample(distance: Double(value % 20) / 10.0, duration: (value % 600) + 60, valid: value % 3 != 0)
}

@inline(never)
func beforeRouteSegments(_ coordinates: [Coordinate]) -> Int {
    let lineSegmentCount = coordinates.count - 1
    let segmentCount = min(lineSegmentCount, 28)
    return (0..<segmentCount).compactMap { index in
        let startIndex = index * lineSegmentCount / segmentCount
        let endIndex = (index + 1) * lineSegmentCount / segmentCount
        guard endIndex > startIndex else { return nil }
        return Array(coordinates[startIndex...endIndex]).count
    }.reduce(0, +)
}

@inline(never)
func afterRouteSegments(_ coordinates: [Coordinate]) -> Int {
    let lineSegmentCount = coordinates.count - 1
    let segmentCount = min(lineSegmentCount, 28)
    var result: [Int] = []
    result.reserveCapacity(segmentCount)
    for index in 0..<segmentCount {
        let startIndex = index * lineSegmentCount / segmentCount
        let endIndex = (index + 1) * lineSegmentCount / segmentCount
        guard endIndex > startIndex else { continue }
        result.append(Array(coordinates[startIndex...endIndex]).count)
    }
    return result.reduce(0, +)
}

@inline(never)
func beforeStatistics(_ records: [RunSample]) -> Double {
    let validRecords = records.filter(\.valid)
    let distance = validRecords.reduce(0.0) { $0 + $1.distance }
    let duration = validRecords.reduce(0) { $0 + $1.duration }
    return distance + Double(duration)
}

@inline(never)
func afterStatistics(_ records: [RunSample]) -> Double {
    var distance = 0.0
    var duration = 0
    for record in records.lazy where record.valid {
        distance += record.distance
        duration += record.duration
    }
    return distance + Double(duration)
}

func measure(_ operation: (Int) -> Double) -> BenchmarkResult {
    var checksum = 0.0
    let start = DispatchTime.now().uptimeNanoseconds
    for iteration in 0..<repeatCount {
        checksum += operation(iteration)
    }
    let elapsed = DispatchTime.now().uptimeNanoseconds - start
    return BenchmarkResult(milliseconds: Double(elapsed) / 1_000_000.0 / Double(repeatCount), checksum: checksum)
}

var beforeCoordinates = coordinates
var afterCoordinates = coordinates
var beforeRecords = records
var afterRecords = records
let beforeRoute = measure { iteration in
    beforeCoordinates[iteration].latitude += Double(iteration) * 0.0000000001
    return Double(beforeRouteSegments(beforeCoordinates))
}
let afterRoute = measure { iteration in
    afterCoordinates[iteration].latitude += Double(iteration) * 0.0000000001
    return Double(afterRouteSegments(afterCoordinates))
}
let beforeStats = measure { iteration in
    beforeRecords[iteration].distance += Double(iteration) * 0.0000001
    return beforeStatistics(beforeRecords)
}
let afterStats = measure { iteration in
    afterRecords[iteration].distance += Double(iteration) * 0.0000001
    return afterStatistics(afterRecords)
}

print("route.before_ms=\(beforeRoute.milliseconds) route.after_ms=\(afterRoute.milliseconds) route.checksum=\(beforeRoute.checksum)/\(afterRoute.checksum)")
print("stats.before_ms=\(beforeStats.milliseconds) stats.after_ms=\(afterStats.milliseconds) stats.checksum=\(beforeStats.checksum)/\(afterStats.checksum)")
