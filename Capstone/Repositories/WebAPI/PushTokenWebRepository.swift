//
//  PushTokenWebRepository.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-11.
//

import Foundation

protocol PushTokenWebRepository: WebRepository {
    func register(devicePushToken: Data) async throws
}

struct RealPushTokenWebRepository: PushTokenWebRepository {
    let session: URLSession
    let baseURL: String = "https://your-server.com/api/push-token"

    func register(devicePushToken: Data) async throws {
        let tokenPayload = ["token": devicePushToken.base64EncodedString()]
        let bodyData = try JSONSerialization.data(withJSONObject: tokenPayload, options: [])
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = ["Content-Type": "application/json"]
        request.httpBody = bodyData
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.unexpectedResponse
        }
    }
}
