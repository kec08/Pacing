import Foundation

let inputCount = 100_000
let batchSize = 4
let iterations = 30
let source = Array(0..<inputCount)

@inline(never) func beforeCapacity() -> Int {
    var result: [Int] = []
    for value in source { result.append(value) }
    return result.count
}
@inline(never) func afterCapacity() -> Int {
    var result: [Int] = []
    result.reserveCapacity(source.count)
    for value in source { result.append(value) }
    return result.count
}
@inline(never) func beforeSlices() -> Int {
    stride(from: 0, to: source.count, by: batchSize)
        .map { Array(source[$0..<min($0 + batchSize, source.count)]) }
        .reduce(0) { $0 + $1.count }
}
@inline(never) func afterSlices() -> Int {
    var count = 0
    for start in stride(from: 0, to: source.count, by: batchSize) {
        count += source[start..<min(start + batchSize, source.count)].count
    }
    return count
}
func measure(_ body: () -> Int) -> Double {
    var checksum = 0
    let start = DispatchTime.now().uptimeNanoseconds
    for _ in 0..<iterations { checksum += body() }
    precondition(checksum == inputCount * iterations)
    return Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000 / Double(iterations)
}
let capacityBefore = measure(beforeCapacity)
let capacityAfter = measure(afterCapacity)
let slicesBefore = measure(beforeSlices)
let slicesAfter = measure(afterSlices)
print("capacity.before_ms=\(capacityBefore) capacity.after_ms=\(capacityAfter) improvement=\((1 - capacityAfter / capacityBefore) * 100)")
print("slices.before_ms=\(slicesBefore) slices.after_ms=\(slicesAfter) improvement=\((1 - slicesAfter / slicesBefore) * 100)")
