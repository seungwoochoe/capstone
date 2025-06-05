//
//  PushTokenWebRepository.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-11.
//

import Foundation

// MARK: - DTOs for Push Token Registration -------------------------------

struct RegisterPushTokenResponse: Decodable {
    let endpointArn: String
}

protocol PushTokenWebRepository: WebRepository {
    /// Sends the raw APNs device token to the backend, which in turn
    /// calls SNS.createPlatformEndpoint(...) and returns an endpointArn.
    /// – Parameter token: the `deviceToken` Data from didRegisterForRemoteNotifications
    /// – Returns: the SNS platform endpoint ARN (i.e. “arn:aws:sns:…”)
    func registerPushToken(_ token: Data) async throws -> String
}

struct RealPushTokenWebRepository: PushTokenWebRepository {
    
    let session: URLSession
    let baseURL: String

    init(session: URLSession = .shared, baseURL: String) {
        self.session = session
        self.baseURL = baseURL
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
