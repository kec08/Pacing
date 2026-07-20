import Foundation
import CryptoKit

struct AppleNonceStore {
    private var rawNonceByHash: [String: String] = [:]

    mutating func register(rawNonce: String) -> String {
        let nonceHash = Self.sha256(rawNonce)
        rawNonceByHash[nonceHash] = rawNonce
        return nonceHash
    }

    mutating func consume(rawNonceHash: String) -> String? {
        rawNonceByHash.removeValue(forKey: rawNonceHash)
    }

    mutating func removeAll() {
        rawNonceByHash.removeAll()
    }

    static func nonceHash(fromIDToken idToken: String) -> String? {
        let parts = idToken.split(separator: ".")
        guard parts.count == 3 else { return nil }

        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        payload.append(String(repeating: "=", count: (4 - payload.count % 4) % 4))

        guard
            let data = Data(base64Encoded: payload),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        return object["nonce"] as? String
    }

    private static func sha256(_ input: String) -> String {
        let hash = SHA256.hash(data: Data(input.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
