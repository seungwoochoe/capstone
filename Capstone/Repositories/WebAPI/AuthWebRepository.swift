//
//  AuthWebRepository.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import Foundation

struct AuthWebRepository: AuthRepository {
    let session: URLSession
    
    func signInWithApple() async throws -> Bool {
        // Implement Sign in with Apple integration.
        // For now, simulate a successful authentication.
        try await Task.sleep(nanoseconds: 500_000_000)
        return true
    }
    
    func signOut() async throws {
        // Simulate sign out.
    }
}
