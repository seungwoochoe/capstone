//
//  KeychainService.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import Foundation
import Security

protocol KeychainService {
    func saveAccessToken(_ token: String) throws
    func saveRefreshToken(_ token: String) throws
    func getAccessToken() throws -> String?
    func getRefreshToken() throws -> String?
    func deleteTokens() throws
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
    
    private let accessTokenAccount = "accessToken"
    private let refreshTokenAccount = "refreshToken"
    
    func saveAccessToken(_ token: String) throws {
        guard let tokenData = token.data(using: .utf8) else {
            throw KeychainError.conversionError
        }
        
        // Delete existing accessToken entry
        let deleteQuery: [String: Any] = [
            kSecClass as String:      kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accessTokenAccount
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Add new access token
        let addQuery: [String: Any] = [
            kSecClass as String:          kSecClassGenericPassword,
            kSecAttrService as String:    service,
            kSecAttrAccount as String:    accessTokenAccount,
            kSecValueData as String:      tokenData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    func saveRefreshToken(_ token: String) throws {
        guard let tokenData = token.data(using: .utf8) else {
            throw KeychainError.conversionError
        }
        
        let deleteQuery: [String: Any] = [
            kSecClass as String:      kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: refreshTokenAccount
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        let addQuery: [String: Any] = [
            kSecClass as String:          kSecClassGenericPassword,
            kSecAttrService as String:    service,
            kSecAttrAccount as String:    refreshTokenAccount,
            kSecValueData as String:      tokenData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    func getAccessToken() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String:          kSecClassGenericPassword,
            kSecAttrService as String:    service,
            kSecAttrAccount as String:    accessTokenAccount,
            kSecReturnData as String:     kCFBooleanTrue as Any,
            kSecMatchLimit as String:     kSecMatchLimitOne
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
    
    func getRefreshToken() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String:          kSecClassGenericPassword,
            kSecAttrService as String:    service,
            kSecAttrAccount as String:    refreshTokenAccount,
            kSecReturnData as String:     kCFBooleanTrue as Any,
            kSecMatchLimit as String:     kSecMatchLimitOne
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
    
    func deleteTokens() throws {
        let deleteAccessQuery: [String: Any] = [
            kSecClass as String:         kSecClassGenericPassword,
            kSecAttrService as String:   service,
            kSecAttrAccount as String:   accessTokenAccount
        ]
        let _ = SecItemDelete(deleteAccessQuery as CFDictionary)
        
        let deleteRefreshQuery: [String: Any] = [
            kSecClass as String:         kSecClassGenericPassword,
            kSecAttrService as String:   service,
            kSecAttrAccount as String:   refreshTokenAccount
        ]
        let _ = SecItemDelete(deleteRefreshQuery as CFDictionary)
    }
}

struct StubKeychainService: KeychainService {
    func saveAccessToken(_ token: String) throws {}
    func saveRefreshToken(_ token: String) throws {}
    func getAccessToken() throws -> String? { nil }
    func getRefreshToken() throws -> String? { nil }
    func deleteTokens() throws {}
}
