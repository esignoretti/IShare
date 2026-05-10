import Foundation
import Security

struct KeychainManager {
    private let serviceName = "com.isare.s3credentials"

    enum KeychainError: Error, LocalizedError {
        case unhandledStatus(OSStatus)
        case itemNotFound
        case duplicateItem
        case dataConversionFailed

        var errorDescription: String? {
            switch self {
            case .unhandledStatus(let status):
                return "Keychain operation failed with status: \(status)"
            case .itemNotFound:
                return "Credential not found in Keychain"
            case .duplicateItem:
                return "Credential already exists in Keychain"
            case .dataConversionFailed:
                return "Failed to convert credential data"
            }
        }
    }

    func saveAccessKey(_ key: String) throws {
        try save(service: serviceName, account: "accessKey", data: Data(key.utf8))
    }

    func readAccessKey() throws -> String {
        let data = try read(service: serviceName, account: "accessKey")
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.dataConversionFailed
        }
        return string
    }

    func saveSecretKey(_ key: String) throws {
        try save(service: serviceName, account: "secretKey", data: Data(key.utf8))
    }

    func readSecretKey() throws -> String {
        let data = try read(service: serviceName, account: "secretKey")
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.dataConversionFailed
        }
        return string
    }

    func deleteAll() throws {
        try delete(service: serviceName, account: "accessKey")
        try delete(service: serviceName, account: "secretKey")
    }

    private func save(service: String, account: String, data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandledStatus(status)
        }
    }

    private func read(service: String, account: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unhandledStatus(status)
        }

        guard let data = result as? Data else {
            throw KeychainError.dataConversionFailed
        }
        return data
    }

    private func delete(service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledStatus(status)
        }
    }
}
