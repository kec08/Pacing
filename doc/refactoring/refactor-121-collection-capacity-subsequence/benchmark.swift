import Foundation

private struct TrackPayload {
    let id: String
    let title: String
    let artist: String
}

private let inputCount = 100_000
private let batchSize = 4
private let repetitionsPerSample = 10
private let sampleCount = 15
private let source = (0..<inputCount).map {
    TrackPayload(id: "track-\($0)", title: "title-\($0 % 100)", artist: "artist-\($0 % 20)")
}

// 실제 호출 경로처럼 각 배치의 모든 트랙 필드를 읽어 checksum을 만든다.
// 단순 count 합산은 릴리스 최적화에서 반복문이 제거될 수 있어 사용하지 않는다.
@inline(never) private func consume(_ tracks: some Sequence<TrackPayload>) -> Int {
    var checksum = 0
    for track in tracks {
        checksum &+= track.id.utf8.count
        checksum &+= track.title.utf8.count
        checksum &+= track.artist.utf8.count
    }
    return checksum
}

@inline(never) private func beforeCapacity() -> Int {
    var result: [TrackPayload] = []
    for value in source { result.append(value) }
    return consume(result)
}

@inline(never) private func afterCapacity() -> Int {
    var result: [TrackPayload] = []
    result.reserveCapacity(source.count)
    for value in source { result.append(value) }
    return consume(result)
}

@inline(never) private func beforeSlices() -> Int {
    let batches = stride(from: 0, to: source.count, by: batchSize).map {
        Array(source[$0..<min($0 + batchSize, source.count)])
    }
    return batches.reduce(0) { $0 &+ consume($1) }
}

@inline(never) private func afterSlices() -> Int {
    var checksum = 0
    for start in stride(from: 0, to: source.count, by: batchSize) {
        let end = min(start + batchSize, source.count)
        checksum &+= consume(source[start..<end])
    }
    return checksum
}

private func median(_ values: [Double]) -> Double {
    let sorted = values.sorted()
    return sorted[sorted.count / 2]
}

private func measure(_ body: () -> Int) -> Double {
    let expected = body()
    for _ in 0..<3 { precondition(body() == expected) } // warm-up + 결과 동등성

    let samples = (0..<sampleCount).map { _ -> Double in
        let start = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<repetitionsPerSample { precondition(body() == expected) }
        return Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000 / Double(repetitionsPerSample)
    }
    return median(samples)
}

let capacityBefore = measure(beforeCapacity)
let capacityAfter = measure(afterCapacity)
let slicesBefore = measure(beforeSlices)
let slicesAfter = measure(afterSlices)

print("capacity.before_ms=\(capacityBefore) capacity.after_ms=\(capacityAfter) improvement=\((1 - capacityAfter / capacityBefore) * 100)")
print("slices.before_ms=\(slicesBefore) slices.after_ms=\(slicesAfter) improvement=\((1 - slicesAfter / slicesBefore) * 100)")
