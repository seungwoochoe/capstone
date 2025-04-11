//
//  AuthInteractor.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import Foundation

struct AuthInteractor {
    let webRepository: AuthRepository
    let keychainService: KeychainService
    
    func signIn() async throws {
        let success = try await webRepository.signInWithApple()
        if success {
            // Save session token securely using Keychain.
            try keychainService.save(token: "dummy_session_token")
        }
    }
    
    func signOut() async throws {
        try await webRepository.signOut()
        try keychainService.deleteToken()
        // Delete any local user data if necessary.
    }
}
