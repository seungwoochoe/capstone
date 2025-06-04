//
//  AuthInteractor.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import Foundation

protocol AuthInteractor {
    func completeSignIn(authorizationCode: String) async throws
    func signOut() async throws
}

struct RealAuthInteractor: AuthInteractor {
    
    let webRepository: AuthWebRepository
    let keychainService: KeychainService

    func completeSignIn(authorizationCode code: String) async throws {
        let authResponse = try await webRepository.exchange(code: code)
        try keychainService.save(token: authResponse.token)
        UserDefaults.standard.set(authResponse.userID, forKey: "userID")
    }

    func signOut() async throws {
        try keychainService.deleteToken()
        // Delete any local user data, if needed
    }
}

struct StubAuthInteractor: AuthInteractor {
    func completeSignIn(authorizationCode: String) async throws {}
    func signOut() async throws {}
}
