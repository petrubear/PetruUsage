import Foundation
import Security

final class KeychainService: KeychainPort {
    func readGenericPassword(service: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status != errSecItemNotFound else { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError.readFailed(service: service, status: status)
        }

        guard let text = String(data: data, encoding: .utf8) else {
            // Attempt hex-decode fallback for macOS keychain items
            return try hexDecodeKeychainData(data)
        }

        return text
    }

    func writeGenericPassword(service: String, data: String) throws {
        guard let encoded = data.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: encoded,
        ]

        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = encoded
            status = SecItemAdd(addQuery as CFDictionary, nil)
        }

        guard status == errSecSuccess else {
            throw KeychainError.writeFailed(service: service, status: status)
        }
    }

    private func hexDecodeKeychainData(_ data: Data) throws -> String? {
        // Some macOS keychain items are hex-encoded UTF-8 bytes
        guard let hexString = String(data: data, encoding: .ascii) else { return nil }

        let hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "0x", with: "")
            .replacingOccurrences(of: "0X", with: "")

        guard hex.count % 2 == 0, hex.allSatisfy({ $0.isHexDigit }) else { return nil }

        var bytes: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<nextIndex], radix: 16) else { return nil }
            bytes.append(byte)
            index = nextIndex
        }

        return String(bytes: bytes, encoding: .utf8)
    }
}

enum KeychainError: LocalizedError {
    case readFailed(service: String, status: OSStatus)
    case writeFailed(service: String, status: OSStatus)
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .readFailed(let service, let status):
            "Keychain read failed for '\(service)': OSStatus \(status)"
        case .writeFailed(let service, let status):
            "Keychain write failed for '\(service)': OSStatus \(status)"
        case .encodingFailed:
            "Failed to encode keychain data"
        }
    }
}
