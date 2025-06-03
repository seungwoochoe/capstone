//
//  AuthInteractor.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import Foundation

protocol AuthInteractor {
    func signIn(with appleToken: String) async throws
    func signOut() async throws
}

struct RealAuthInteractor: AuthInteractor {
    
    let webRepository: AuthWebRepository
    let keychainService: KeychainService

    func signIn(with appleToken: String) async throws {
        let authResponse = try await webRepository.authenticate(with: appleToken)
        try keychainService.save(token: authResponse.token)
        UserDefaults.standard.set(authResponse.userID, forKey: "userID")
    }

    func signOut() async throws {
        try keychainService.deleteToken()
        // Delete any local user data, if needed
    }
}

struct StubAuthInteractor: AuthInteractor {
    func signIn(with appleToken: String) async throws {
        // no-op
    }

    func signOut() async throws {
        // no-op
    }
}
