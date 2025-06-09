//
//  PushTokenWebRepository.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-11.
//

import Foundation
import OSLog

struct RegisterPushTokenResponse: Codable {
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
    
    private let logger = Logger.forType(RealPushTokenWebRepository.self)
    
    init(session: URLSession = .shared, baseURL: String, accessTokenProvider: AccessTokenProvider) {
        self.session = session
        self.baseURL = baseURL
        self.tokenProvider = accessTokenProvider
    }
    
    func registerPushToken(_ token: Data) async throws -> String {
        let hexToken = token.map { String(format: "%02x", $0) }.joined()
        
        let payload = ["token": hexToken]
        let bodyData: Data
        do {
            bodyData = try JSONEncoder().encode(payload)
        } catch {
            logger.error("Failed to encode push token payload. Error: \(error.localizedDescription, privacy: .public).")
            throw error
        }
        
        do {
            let response: RegisterPushTokenResponse = try await call(
                endpoint: API.Register(bodyData: bodyData)
            )
            logger.debug("Push token registered. Endpoint ARN: \(response.endpointArn).")
            return response.endpointArn
        } catch {
            logger.error("Push token registration failed. Error: \(error.localizedDescription, privacy: .public).")
            throw error
        }
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
