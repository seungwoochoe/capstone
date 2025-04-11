//
//  AuthInteractor.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import Foundation

protocol AuthInteractor {
    func signIn() async throws
    func signOut() async throws
}

struct RealAuthInteractor: AuthInteractor {
    
    let webRepository: AuthenticationWebRepository
    let keychainService: KeychainService
    
    func signIn() async throws {
        let authResponse = try await webRepository.authenticate(with: "apple_token_placeholder")
//        try keychainService.save(token: authResponse.token)
    }
    
    func signOut() async throws {
//        try await webRepository.signOut()
//        try keychainService.deleteToken()
        
        // Delete any local user data.
    }
}

struct StubAuthInteractor: AuthInteractor {
    
    func signIn() async throws {
        
    }
    
    func signOut() async throws {
        
    }
}
