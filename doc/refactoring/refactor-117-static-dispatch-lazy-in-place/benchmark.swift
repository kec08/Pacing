import Foundation

struct Coordinate {
    var latitude: Double
    let longitude: Double
}

struct RunSample {
    var distance: Double
    let duration: Int
    let isPaceValid: Bool
    let isInWeek: Bool
}

struct Measurement {
    let milliseconds: Double
    let checksum: Double
}

let inputCount = 100_000
let iterationsPerSample = 30
let sampleCount = 5
let runtimeSeed = UInt64(Date().timeIntervalSince1970 * 1_000_000)

let sourceRecords = (0..<inputCount).map { index in
    let value = (index * 17 + Int(runtimeSeed & 0xff)) % 1_000
    return RunSample(
        distance: Double(value % 20) / 10.0,
        duration: (value % 600) + 60,
        isPaceValid: value % 3 != 0,
        isInWeek: value % 5 < 3
    )
}
let sourceCoordinates = (0..<inputCount).map { index in
    let value = Double((index * 31) ^ Int(runtimeSeed & 0xffff))
    return Coordinate(
        latitude: 37.0 + value * 0.00000001,
        longitude: 127.0 + value * 0.00000001
    )
}

@inline(never)
func beforeStatistics(_ records: [RunSample]) -> Double {
    let weekly = records.filter(\.isInWeek)
    let validPaceRecords = weekly.filter(\.isPaceValid)
    let totalDistance = weekly.reduce(0.0) { $0 + $1.distance }
    let totalDuration = weekly.reduce(0) { $0 + $1.duration }
    let validDistance = validPaceRecords.reduce(0.0) { $0 + $1.distance }
    let validDuration = validPaceRecords.reduce(0) { $0 + $1.duration }
    return totalDistance + Double(totalDuration) + validDistance + Double(validDuration)
}

@inline(never)
func afterStatistics(_ records: [RunSample]) -> Double {
    var totalDistance = 0.0
    var totalDuration = 0
    var validDistance = 0.0
    var validDuration = 0

    for record in records.lazy where record.isInWeek {
        totalDistance += record.distance
        totalDuration += record.duration
        if record.isPaceValid {
            validDistance += record.distance
            validDuration += record.duration
        }
    }

    return totalDistance + Double(totalDuration) + validDistance + Double(validDuration)
}

@inline(never)
func beforeRouteBounds(_ coordinates: [Coordinate]) -> Double {
    let latitudes = coordinates.map(\.latitude)
    let longitudes = coordinates.map(\.longitude)
    return (latitudes.min() ?? 0) + (latitudes.max() ?? 0)
        + (longitudes.min() ?? 0) + (longitudes.max() ?? 0)
}

@inline(never)
func afterRouteBounds(_ coordinates: [Coordinate]) -> Double {
    guard let first = coordinates.first else { return 0 }
    var minLatitude = first.latitude
    var maxLatitude = first.latitude
    var minLongitude = first.longitude
    var maxLongitude = first.longitude

    for coordinate in coordinates.dropFirst() {
        minLatitude = min(minLatitude, coordinate.latitude)
        maxLatitude = max(maxLatitude, coordinate.latitude)
        minLongitude = min(minLongitude, coordinate.longitude)
        maxLongitude = max(maxLongitude, coordinate.longitude)
    }

    return minLatitude + maxLatitude + minLongitude + maxLongitude
}

func measure(_ operation: (Int) -> Double) -> Measurement {
    var checksum = 0.0
    let startedAt = DispatchTime.now().uptimeNanoseconds
    for iteration in 0..<iterationsPerSample {
        checksum += operation(iteration)
    }
    let elapsed = DispatchTime.now().uptimeNanoseconds - startedAt
    return Measurement(
        milliseconds: Double(elapsed) / 1_000_000.0 / Double(iterationsPerSample),
        checksum: checksum
    )
}

func mean(_ values: [Double]) -> Double {
    values.reduce(0, +) / Double(values.count)
}

func standardDeviation(_ values: [Double]) -> Double {
    let average = mean(values)
    return sqrt(values.reduce(0) { $0 + pow($1 - average, 2) } / Double(values.count))
}

var statisticsBefore: [Double] = []
var statisticsAfter: [Double] = []
var routeBefore: [Double] = []
var routeAfter: [Double] = []
var checksumsMatch = true

for sample in 0..<sampleCount {
    var beforeRecords = sourceRecords
    var afterRecords = sourceRecords
    var beforeCoordinates = sourceCoordinates
    var afterCoordinates = sourceCoordinates

    let beforeStats = measure { iteration in
        beforeRecords[(sample + iteration) % beforeRecords.count].distance += Double(iteration) * 0.0000001
        return beforeStatistics(beforeRecords)
    }
    let afterStats = measure { iteration in
        afterRecords[(sample + iteration) % afterRecords.count].distance += Double(iteration) * 0.0000001
        return afterStatistics(afterRecords)
    }
    let beforeBounds = measure { iteration in
        beforeCoordinates[(sample + iteration) % beforeCoordinates.count].latitude += Double(iteration) * 0.0000000001
        return beforeRouteBounds(beforeCoordinates)
    }
    let afterBounds = measure { iteration in
        afterCoordinates[(sample + iteration) % afterCoordinates.count].latitude += Double(iteration) * 0.0000000001
        return afterRouteBounds(afterCoordinates)
    }

    statisticsBefore.append(beforeStats.milliseconds)
    statisticsAfter.append(afterStats.milliseconds)
    routeBefore.append(beforeBounds.milliseconds)
    routeAfter.append(afterBounds.milliseconds)
    checksumsMatch = checksumsMatch
        && beforeStats.checksum == afterStats.checksum
        && beforeBounds.checksum == afterBounds.checksum
}

let statisticsImprovement = (1 - mean(statisticsAfter) / mean(statisticsBefore)) * 100
let routeImprovement = (1 - mean(routeAfter) / mean(routeBefore)) * 100

print("statistics.before_ms=\(mean(statisticsBefore)) ± \(standardDeviation(statisticsBefore))")
print("statistics.after_ms=\(mean(statisticsAfter)) ± \(standardDeviation(statisticsAfter))")
print("statistics.improvement_percent=\(statisticsImprovement)")
print("route.before_ms=\(mean(routeBefore)) ± \(standardDeviation(routeBefore))")
print("route.after_ms=\(mean(routeAfter)) ± \(standardDeviation(routeAfter))")
print("route.improvement_percent=\(routeImprovement)")
print("checksums_match=\(checksumsMatch)")
