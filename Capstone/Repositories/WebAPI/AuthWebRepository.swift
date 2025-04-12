//
//  AuthWebRepository.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import Foundation

struct AuthResponse: Codable, Equatable {
    let token: String
    let userID: String
}

protocol AuthWebRepository: WebRepository {
    func authenticate(with appleToken: String) async throws -> AuthResponse
}

struct RealAuthenticationWebRepository: AuthWebRepository {
    let session: URLSession
    let baseURL: String = "https://your-server.com/api/auth"

    func authenticate(with appleToken: String) async throws -> AuthResponse {
        return try await call(endpoint: API.authenticate(appleToken: appleToken))
    }
}

extension RealAuthenticationWebRepository {
    enum API {
        case authenticate(appleToken: String)
    }
}

extension RealAuthenticationWebRepository.API: APICall {
    var path: String {
        switch self {
        case let .authenticate(appleToken):
            return "/signin?token=\(appleToken)"
        }
    }
    var method: String { "POST" }
    var headers: [String: String]? {
        ["Content-Type": "application/json"]
    }
    func body() throws -> Data? {
        return nil  // Or serialize a JSON payload if needed.
    }
}
