//
//  KeychainService.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import Foundation
import Security

protocol KeychainService {
    /// Save the given string as the “authToken” in Keychain.
    func save(token: String) throws

    /// Delete any “authToken” entry from Keychain.
    func deleteToken() throws

    /// Attempt to read back the saved token.
    /// - Returns: the token string if one exists, or nil if not found.
    func getToken() throws -> String?
}

enum KeychainError: Error, LocalizedError {
    case unexpectedStatus(OSStatus)
    case conversionError

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            return "Keychain operation failed with status \(status)"
        case .conversionError:
            return "Failed to convert token to Data or vice‐versa."
        }
    }
}

struct RealKeychainService: KeychainService {
    private let service = Bundle.main.bundleIdentifier ?? "Capstone"
    private let account = "authToken"

    func save(token: String) throws {
        guard let tokenData = token.data(using: .utf8) else {
            throw KeychainError.conversionError
        }

        // Delete any existing entry first
        let deleteQuery: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Now add the new value
        let addQuery: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      service,
            kSecAttrAccount as String:      account,
            kSecValueData as String:        tokenData,
            kSecAttrAccessible as String:   kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func deleteToken() throws {
        let deleteQuery: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(deleteQuery as CFDictionary)
        // errSecItemNotFound is fine—means nothing was there to begin with.
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func getToken() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      service,
            kSecAttrAccount as String:      account,
            kSecReturnData as String:       kCFBooleanTrue as Any,
            kSecMatchLimit as String:       kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard
                let data = item as? Data,
                let tokenString = String(data: data, encoding: .utf8)
            else {
                throw KeychainError.conversionError
            }
            return tokenString

        case errSecItemNotFound:
            return nil

        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }
}

struct StubKeychainService: KeychainService {
    func save(token: String) throws { /* no‐op */ }
    func deleteToken() throws { /* no‐op */ }
    func getToken() throws -> String? { return nil }
}
