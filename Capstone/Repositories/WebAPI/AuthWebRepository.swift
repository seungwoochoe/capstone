//
//  AuthWebRepository.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import Foundation
import OSLog

struct AuthResponse: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let idToken: String
    let userID: String?
}

struct CognitoTokenResponse: Decodable {
    let id_token: String
    let access_token: String
    let refresh_token: String?
    let expires_in: Int
    let token_type: String
}

// MARK: - AuthWebRepository

protocol AuthWebRepository {
    func makeHostedUISignInURL(state: String, nonce: String) -> URL
    func exchange(code: String) async throws -> AuthResponse
    func refreshTokens(using refreshToken: String) async throws -> AuthResponse
}

struct RealAuthenticationWebRepository: AuthWebRepository {
    
    private let session: URLSession
    private let baseURL: String
    private let userPoolDomain: String
    private let clientId: String
    private let redirectUri: String
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: #file)
    
    init(session: URLSession, baseURL: String, userPoolDomain: String, clientId: String, redirectUri: String) {
        self.session = session
        self.baseURL = baseURL
        self.userPoolDomain = userPoolDomain
        self.clientId = clientId
        self.redirectUri = redirectUri
    }
    
    func makeHostedUISignInURL(state: String, nonce: String) -> URL {
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host   = userPoolDomain
        comps.path   = "/oauth2/authorize"
        comps.queryItems = [
            .init(name: "response_type",     value: "code"),
            .init(name: "client_id",         value: clientId),
            .init(name: "redirect_uri",      value: redirectUri),
            .init(name: "scope",             value: "openid email profile"),
            .init(name: "identity_provider", value: "SignInWithApple"),
            .init(name: "state",             value: state),
            .init(name: "nonce",             value: nonce)
        ]
        return comps.url!
    }
    
    func exchange(code: String) async throws -> AuthResponse {
        let body =
        "grant_type=authorization_code" +
        "&client_id=\(clientId)" +
        "&code=\(code)" +
        "&redirect_uri=\(redirectUri)"
        let url = URL(string: "https://\(userPoolDomain)/oauth2/token")!
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await session.data(for: req)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            logger.error("Got unexpected status code: \(String(describing: response))")
            throw APIError.unexpectedResponse
        }
        
        let cognito = try JSONDecoder().decode(CognitoTokenResponse.self, from: data)
        let userId = try extractUserID(from: cognito.id_token)
        
        return AuthResponse(
            accessToken: cognito.access_token,
            refreshToken: cognito.refresh_token ?? "",
            expiresIn: cognito.expires_in,
            idToken: cognito.id_token,
            userID: userId
        )
    }
    
    func refreshTokens(using refreshToken: String) async throws -> AuthResponse {
        let body =
        "grant_type=refresh_token" +
        "&client_id=\(clientId)" +
        "&refresh_token=\(refreshToken)"
        let url = URL(string: "https://\(userPoolDomain)/oauth2/token")!
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await session.data(for: req)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            logger.error("Got unexpected status code: \(String(describing: response))")
            throw APIError.unexpectedResponse
        }
        
        let cognito = try JSONDecoder().decode(CognitoTokenResponse.self, from: data)
        
        return AuthResponse(
            accessToken: cognito.access_token,
            refreshToken: cognito.refresh_token ?? refreshToken,
            expiresIn: cognito.expires_in,
            idToken: cognito.id_token,
            userID: nil
        )
    }
    
    private func extractUserID(from idToken: String) throws -> String {
        struct Payload: Decodable {
            let sub: String
        }
        
        let parts = idToken.split(separator: ".")
        guard parts.count >= 2,
              let data = Data(base64Encoded: String(parts[1])) else {
            throw APIError.unexpectedResponse
        }
        return try JSONDecoder().decode(Payload.self, from: data).sub
    }
}
