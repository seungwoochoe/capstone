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

struct CognitoTokenResponse: Decodable {
    let id_token: String
    let access_token: String
    let refresh_token: String?
    let expires_in: Int
    let token_type: String
}

// MARK: – Public API ----------------------------------------------------
protocol AuthWebRepository: WebRepository {
    func makeHostedUISignInURL(state: String, nonce: String) -> URL
    func exchange(code: String) async throws -> AuthResponse
}

struct RealAuthenticationWebRepository: AuthWebRepository {
    
    let session: URLSession
    let baseURL: String
    let userPoolDomain: String
    let clientId: String
    let redirectUri: String
    
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

        var req = URLRequest(url:
            URL(string: "https://\(userPoolDomain)/oauth2/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = body.data(using: .utf8)

        let (data, response) = try await session.data(for: req)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw APIError.unexpectedResponse
        }

        let cognito = try JSONDecoder().decode(CognitoTokenResponse.self, from: data)

        // keep the shape you already use elsewhere
        return AuthResponse(token: cognito.id_token,
                            userID: try Self.userId(from: cognito.id_token))
    }

    private static func userId(from idToken: String) throws -> String {
        // very small helper to extract the Cognito "sub" from the JWT payload
        struct Payload: Decodable { let sub: String }
        let parts = idToken.split(separator: ".")
        guard parts.count >= 2,
              let data = Data(base64Encoded: String(parts[1])) else {
            throw APIError.unexpectedResponse
        }
        return try JSONDecoder().decode(Payload.self, from: data).sub
    }
}
