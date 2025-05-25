//
//  KeychainService.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import Foundation

protocol KeychainService {
    
}

struct RealKeychainService: KeychainService {
    func save(token: String) throws {
        // Implement Keychain save logic.
    }
    
    func deleteToken() throws {
        // Implement Keychain delete logic.
    }
}

struct StubKeychainService: KeychainService {
    
}
