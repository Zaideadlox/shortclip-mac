import Foundation
import Security

enum KeychainError: LocalizedError, Sendable {
    case unhandledError(status: OSStatus)
    case encodingError

    var errorDescription: String? {
        switch self {
        case .unhandledError(let status):
            return "Keychain operation failed with status \(status)."
        case .encodingError:
            return "Failed to encode or decode secure data."
        }
    }
}

final class KeychainService: Sendable {
    private let service: String

    init(service: String = "com.tiktokdesktop.mac.auth") {
        self.service = service
    }

    func save(_ data: Data, forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }
    }

    func load(forKey key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }
        return item as? Data
    }

    func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    func saveCodable<T: Encodable>(_ value: T, forKey key: String) throws {
        let data = try JSONEncoder().encode(value)
        try save(data, forKey: key)
    }

    func loadCodable<T: Decodable>(_ type: T.Type, forKey key: String) throws -> T? {
        guard let data = try load(forKey: key) else { return nil }
        return try JSONDecoder().decode(type, from: data)
    }
}
