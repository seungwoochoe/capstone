//
//  PushTokenWebRepository.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-11.
//

import Foundation

protocol PushTokenWebRepository: WebRepository {
    func registerPushToken(_ token: Data) async throws
    func unregisterPushToken(_ token: Data) async throws
}

struct RealPushTokenWebRepository: PushTokenWebRepository {
    
    let session: URLSession
    let baseURL: String

    init(session: URLSession = .shared, baseURL: String) {
        self.session = session
        self.baseURL = baseURL
    }

    func registerPushToken(_ token: Data) async throws {
        let hexToken = token.map { String(format: "%02x", $0) }.joined()
        let payload = ["token": hexToken]
        let bodyData = try JSONEncoder().encode(payload)
        _ = try await call(endpoint: API.Register(bodyData: bodyData)) as EmptyResponse
    }

    func unregisterPushToken(_ token: Data) async throws {
        let hexToken = token.map { String(format: "%02x", $0) }.joined()
        let payload = ["token": hexToken]
        let bodyData = try JSONEncoder().encode(payload)
        _ = try await call(endpoint: API.Unregister(bodyData: bodyData)) as EmptyResponse
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

        /// DELETE /devices/push-token
        struct Unregister: APICall {
            let bodyData: Data
            var path: String { "/devices/push-token" }
            var method: String { "DELETE" }
            var headers: [String: String]? { ["Content-Type": "application/json"] }
            func body() throws -> Data? { bodyData }
        }
    }

    /// Dummy type for 204 No Content
    private struct EmptyResponse: Decodable {}
}
