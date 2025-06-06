//
//  PushTokenWebRepository.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-11.
//

import Foundation

struct RegisterPushTokenResponse: Decodable {
    let endpointArn: String
}

// MARK: - PushTokenWebRepository

protocol PushTokenWebRepository: WebRepository {
    func registerPushToken(_ token: Data) async throws -> String
}

// MARK: - RealPushTokenWebRepository

struct RealPushTokenWebRepository: PushTokenWebRepository {
    
    let session: URLSession
    let baseURL: String
    let tokenProvider: AccessTokenProvider

    init(session: URLSession = .shared, baseURL: String, accessTokenProvider: AccessTokenProvider) {
        self.session = session
        self.baseURL = baseURL
        self.tokenProvider = accessTokenProvider
    }

    func registerPushToken(_ token: Data) async throws -> String {
        // Convert Data to hex
        let hexToken = token.map { String(format: "%02x", $0) }.joined()
        let payload = ["token": hexToken]
        let bodyData = try JSONEncoder().encode(payload)
        
        let response: RegisterPushTokenResponse = try await call(
            endpoint: API.Register(bodyData: bodyData)
        )
        return response.endpointArn
    }
}

private extension RealPushTokenWebRepository {
    enum API {
        /// POST /devices/push-token
        struct Register: APICall {
            let bodyData: Data
            var path: String { "/devices/push-token" }
            var method: String { "POST" }
            var headers: [String: String]? { ["Content-Type": "application/json"] }
            func body() throws -> Data? { bodyData }
        }
    }
}
