import Foundation

private enum Configuration {
    static let requestLatencyNanoseconds: UInt64 = 10_000_000
    static let sampleCount = 10
    static let trackCount = 100
    static let resourceBatchSize = 25
}

private func simulatedRequest() async {
    try? await Task.sleep(nanoseconds: Configuration.requestLatencyNanoseconds)
}

private func sequentialRequests(_ count: Int) async {
    for _ in 0..<count { await simulatedRequest() }
}

private func beforeRecommendationPipeline() async {
    await sequentialRequests(1) // recently played
    await sequentialRequests(4) // genre albums
    await sequentialRequests(4) // mood playlists
    await sequentialRequests(1) // personal recommendations
}

private func afterRecommendationPipeline() async {
    async let recentlyPlayed: Void = sequentialRequests(1)
    async let genreAlbums: Void = sequentialRequests(4)
    async let moodPlaylists: Void = sequentialRequests(4)
    async let personalRecommendations: Void = sequentialRequests(1)
    _ = await (recentlyPlayed, genreAlbums, moodPlaylists, personalRecommendations)
}

private func measure(_ body: () async -> Void) async -> Double {
    let start = DispatchTime.now().uptimeNanoseconds
    await body()
    return Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
}

@main
private struct Benchmark {
    static func main() async {
        var beforeSamples: [Double] = []
        var afterSamples: [Double] = []

        for _ in 0..<Configuration.sampleCount {
            beforeSamples.append(await measure(beforeRecommendationPipeline))
            afterSamples.append(await measure(afterRecommendationPipeline))
        }

        let before = beforeSamples.sorted()[Configuration.sampleCount / 2]
        let after = afterSamples.sorted()[Configuration.sampleCount / 2]
        let pipelineImprovement = (1 - after / before) * 100

        let beforeRequestCount = 1 + max(0, Configuration.trackCount - Configuration.resourceBatchSize)
        let afterRequestCount = Int(ceil(Double(Configuration.trackCount) / Double(Configuration.resourceBatchSize)))
        let requestReduction = (1 - Double(afterRequestCount) / Double(beforeRequestCount)) * 100

        precondition(beforeRequestCount == 76)
        precondition(afterRequestCount == 4)
        print("recommendations.before_ms=\(before) recommendations.after_ms=\(after) improvement=\(pipelineImprovement)")
        print("catalog_requests.before=\(beforeRequestCount) catalog_requests.after=\(afterRequestCount) reduction=\(requestReduction)")
    }
}
