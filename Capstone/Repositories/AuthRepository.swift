//
//  AuthRepository.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import Foundation

protocol AuthRepository {
    func signInWithApple() async throws -> Bool
    func signOut() async throws
}
