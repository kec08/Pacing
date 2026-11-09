import Foundation
import Security

enum NaverCredentialStore {
    private static let service = "com.pacing.naver-login"
    private static let refreshTokenAccount = "refresh-token"

    static func save(refreshToken: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: refreshTokenAccount,
        ]
        SecItemDelete(query as CFDictionary)

        var item = query
        item[kSecValueData] = Data(refreshToken.utf8)
        item[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NaverCredentialStoreError.keychain(status)
        }
    }

    static func refreshToken() -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: refreshTokenAccount,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func remove() {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: refreshTokenAccount,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum NaverCredentialStoreError: LocalizedError {
    case keychain(OSStatus)

    var errorDescription: String? {
        "네이버 로그인 정보를 안전하게 저장하지 못했어요. 다시 시도해주세요."
    }
}
