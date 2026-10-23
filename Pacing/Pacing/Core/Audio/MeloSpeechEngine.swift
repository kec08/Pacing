import Foundation
import OnnxRuntimeBindings

/// Runs the bundled Korean MeloTTS ONNX model off the main thread.
final class MeloSpeechEngine {
    static let shared = MeloSpeechEngine()

    private let queue = DispatchQueue(label: "pacing.melotts", qos: .userInitiated)
    private let lock = NSLock()
    private var didAttemptLoad = false
    private var environment: ORTEnv?
    private var session: ORTSession?
    private var tokenizer: MeloKoreanTokenizer?

    var isReady: Bool {
        lock.lock()
        defer { lock.unlock() }
        return session != nil && tokenizer != nil
    }

    private init() {}

    func prepare() {
        queue.async { [self] in
            guard !didAttemptLoad else { return }
            didAttemptLoad = true
            do {
                guard let modelURL = Bundle.main.url(forResource: "melotts_kr_int8", withExtension: "onnx"),
                      let lexiconURL = Bundle.main.url(forResource: "korean_lexicon", withExtension: "json")
                else { throw MeloError.missingResources }
                let lexicon = try JSONDecoder().decode([String: [Int64]].self, from: Data(contentsOf: lexiconURL))
                let environment = try ORTEnv(loggingLevel: .warning)
                let options = try ORTSessionOptions()
                let loadedSession = try ORTSession(
                    env: environment,
                    modelPath: modelURL.path,
                    sessionOptions: options
                )
                lock.lock()
                self.environment = environment
                tokenizer = MeloKoreanTokenizer(pronunciations: lexicon)
                session = loadedSession
                lock.unlock()
            } catch {
                NSLog("MeloTTS model loading failed: %@", String(describing: error))
            }
        }
    }

    func synthesize(_ text: String, completion: @escaping (Data?) -> Void) {
        queue.async { [self] in
            let audio: Data?
            do {
                guard let session, let tokenizer,
                      let tokens = tokenizer.tokenIDs(for: text)
                else { throw MeloError.unsupportedText }
                let startedAt = CFAbsoluteTimeGetCurrent()
                audio = try makeWAV(tokens: tokens, session: session)
                NSLog("MeloTTS inference: %.3f seconds", CFAbsoluteTimeGetCurrent() - startedAt)
            } catch {
                NSLog("MeloTTS synthesis failed: %@", String(describing: error))
                audio = nil
            }
            DispatchQueue.main.async { completion(audio) }
        }
    }

    private func makeWAV(tokens: [Int64], session: ORTSession) throws -> Data {
        let length = tokens.count
        guard length > 0, length < 2_048 else { throw MeloError.unsupportedText }
        var buffers: [NSMutableData] = []

        func tensor<T>(_ values: [T], type: ORTTensorElementDataType, shape: [NSNumber]) throws -> ORTValue {
            let data = values.withUnsafeBytes { bytes in
                NSMutableData(bytes: bytes.baseAddress!, length: bytes.count)
            }
            buffers.append(data)
            return try ORTValue(tensorData: data, elementType: type, shape: shape)
        }

        let blankAwareTone = tokens.map { $0 == 0 ? Int64(0) : 11 }
        let blankAwareLanguage = tokens.map { $0 == 0 ? Int64(0) : 4 }
        let textShape: [NSNumber] = [1, NSNumber(value: length)]
        let inputs: [String: ORTValue] = [
            "x": try tensor(tokens, type: .int64, shape: textShape),
            "x_lengths": try tensor([Int64(length)], type: .int64, shape: [1]),
            "sid": try tensor([Int64(0)], type: .int64, shape: [1]),
            "tone": try tensor(blankAwareTone, type: .int64, shape: textShape),
            "language": try tensor(blankAwareLanguage, type: .int64, shape: textShape),
            "noise_scale": try tensor([Float(0.6)], type: .float, shape: []),
            "length_scale": try tensor([Float(1.04)], type: .float, shape: []),
            "noise_scale_w": try tensor([Float(0.8)], type: .float, shape: []),
            "sdp_ratio": try tensor([Float(0.2)], type: .float, shape: [])
        ].merging([
            "bert": try zeroTensor(shape: [1, 1_024, NSNumber(value: length)], buffers: &buffers),
            "ja_bert": try zeroTensor(shape: [1, 768, NSNumber(value: length)], buffers: &buffers)
        ]) { first, _ in first }

        let outputs = try withExtendedLifetime(buffers) {
            try session.run(withInputs: inputs, outputNames: Set(["audio"]), runOptions: nil)
        }
        guard let waveform = outputs["audio"] else { throw MeloError.invalidOutput }
        let samples = try waveform.tensorData()
        guard samples.length > 0, samples.length % MemoryLayout<Float>.size == 0,
              samples.length <= 44_100 * 120 * MemoryLayout<Float>.size
        else { throw MeloError.invalidOutput }
        return try Self.wavData(from: samples)
    }

    private func zeroTensor(shape: [NSNumber], buffers: inout [NSMutableData]) throws -> ORTValue {
        let count = shape.reduce(1) { $0 * $1.intValue }
        guard let data = NSMutableData(length: count * MemoryLayout<Float>.size) else {
            throw MeloError.invalidOutput
        }
        buffers.append(data)
        return try ORTValue(tensorData: data, elementType: .float, shape: shape)
    }

    private static func wavData(from samples: NSMutableData) throws -> Data {
        let count = samples.length / MemoryLayout<Float>.size
        let source = samples.bytes.assumingMemoryBound(to: Float.self)
        let payloadSize = count * MemoryLayout<Int16>.size
        guard payloadSize <= Int(UInt32.max) - 36 else { throw MeloError.invalidOutput }

        var data = Data(capacity: 44 + payloadSize)
        data.append(contentsOf: "RIFF".utf8)
        data.appendLittleEndian(UInt32(36 + payloadSize))
        data.append(contentsOf: "WAVEfmt ".utf8)
        data.appendLittleEndian(UInt32(16))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(UInt16(1))
        // Play 44.1 kHz model samples at 48 kHz for a slightly brighter, quicker voice.
        data.appendLittleEndian(UInt32(48_000))
        data.appendLittleEndian(UInt32(48_000 * 2))
        data.appendLittleEndian(UInt16(2))
        data.appendLittleEndian(UInt16(16))
        data.append(contentsOf: "data".utf8)
        data.appendLittleEndian(UInt32(payloadSize))
        var previous: Float = 0
        for index in 0..<count {
            let sample = source[index]
            guard sample.isFinite else { throw MeloError.invalidOutput }
            let brightened = sample + 0.12 * (sample - previous)
            previous = sample
            let value = Int16((max(-1, min(1, brightened)) * 32_767).rounded())
            data.appendLittleEndian(UInt16(bitPattern: value))
        }
        return data
    }
}

private enum MeloError: Error {
    case missingResources
    case unsupportedText
    case invalidOutput
}

private extension Data {
    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }
}
