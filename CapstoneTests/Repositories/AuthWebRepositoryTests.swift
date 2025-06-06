//
//  AuthWebRepositoryTests.swift
//  CapstoneTests
//
//  Created by Seungwoo Choe on 2025-06-06.
//

import Foundation
import Testing
@testable import Capstone

@Suite("AuthWebRepositoryTests", .serialized)
struct RealAuthenticationWebRepositoryTests {
    
    private let host        = "test.auth.us-east-1.amazoncognito.com"
    private let clientID    = "abc123"
    private let redirectURI = "test://signin-callback"
    
    private func makeRepository(
        httpStatus: Int = 200,
        json: [String: Any]? = nil,
        onRequest: ((URLRequest) throws -> Void)? = nil
    ) -> RealAuthenticationWebRepository {
        
        MockURLProtocol.handler = { request in
            try onRequest?(request)
            
            let data = try! JSONSerialization.data(
                withJSONObject: json ?? [:],
                options: []
            )
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: httpStatus,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, data)
        }
        
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: cfg)
        
        return RealAuthenticationWebRepository(
            session: session,
            baseURL: "",
            userPoolDomain: host,
            clientId: clientID,
            redirectUri: redirectURI
        )
    }
    
    private func tokenResponse(
        access: String = "access-token",
        refresh: String = "refresh-token",
        userID: String = "uid-42",
        expires: Int = 3600
    ) -> [String: Any] {
        
        let header   = #"{"alg":"HS256","typ":"JWT"}"#.data(using: .utf8)!.base64URLEncoded()
        let payload  = #"{"sub":"\#(userID)"}"#.data(using: .utf8)!.base64URLEncoded()
        let jwt      = "\(header).\(payload).sig"
        
        return [
            "id_token":      jwt,
            "access_token":  access,
            "refresh_token": refresh,
            "expires_in":    expires,
            "token_type":    "Bearer"
        ]
    }
    
    private func extractBodyString(from request: URLRequest) throws -> String {
        let stream = try #require(request.httpBodyStream)
        stream.open()
        defer { stream.close() }
        
        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            guard read > 0 else { break }
            data.append(buffer, count: read)
        }
        
        guard let str = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        return str
    }
    
    // MARK: - Individual Tests
    
    @Test("Hosted-UI URL contains all required components")
    func hostedUISignInURL() {
        let repo  = makeRepository()
        let url   = repo.makeHostedUISignInURL(state: "state-abc", nonce: "nonce-xyz")
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        
        #expect(comps.scheme == "https")
        #expect(comps.host == host)
        #expect(comps.path == "/oauth2/authorize")
        
        let items = Dictionary(uniqueKeysWithValues: comps.queryItems!.map { ($0.name, $0.value!) })
        
        #expect(items["response_type"]     == "code")
        #expect(items["client_id"]         == clientID)
        #expect(items["redirect_uri"]      == redirectURI)
        #expect(items["scope"]             == "openid email profile")
        #expect(items["identity_provider"] == "SignInWithApple")
        #expect(items["state"]             == "state-abc")
        #expect(items["nonce"]             == "nonce-xyz")
    }
    
    @Test("exchange(code:) succeeds and maps response to AuthResponse")
    func exchangeSuccess() async throws {
        var capturedBody: String?
        
        let repo = makeRepository(
            json: tokenResponse(userID: "user-123"),
            onRequest: { capturedBody = try extractBodyString(from: $0) }
        )
        
        let auth = try await repo.exchange(code: "auth-code")
        
        #expect(auth.accessToken == "access-token")
        #expect(auth.refreshToken == "refresh-token")
        #expect(auth.expiresIn == 3600)
        #expect(auth.userID == "user-123")
        
        #expect(capturedBody?.contains("grant_type=authorization_code") == true)
        #expect(capturedBody?.contains("code=auth-code") == true)
        #expect(capturedBody?.contains("client_id=\(clientID)") == true)
        #expect(capturedBody?.contains("redirect_uri=\(redirectURI)") == true)
    }
    
    @Test("exchange(code:) propagates non-200 responses as APIError.unexpectedResponse")
    func exchangeFailure() async {
        let repo = makeRepository(httpStatus: 400)
        
        do {
            _ = try await repo.exchange(code: "bad-code")
            #expect(Bool(false))          // should never reach here
        } catch APIError.unexpectedResponse {
            #expect(true)                 // expected path
        } catch {
            #expect(Bool(false))          // wrong error
        }
    }
    
    @Test("refreshTokens(using:) succeeds and maps response to AuthResponse")
    func refreshSuccess() async throws {
        var capturedBody: String?
        
        let repo = makeRepository(
            json: tokenResponse(refresh: "refresh-NEW"),
            onRequest: { capturedBody = try extractBodyString(from: $0) }
        )
        
        let auth = try await repo.refreshTokens(using: "refresh-OLD")
        
        #expect(auth.accessToken == "access-token")
        #expect(auth.refreshToken == "refresh-NEW")
        #expect(auth.userID == nil)
        
        #expect(capturedBody?.contains("grant_type=refresh_token") == true)
        #expect(capturedBody?.contains("refresh_token=refresh-OLD") == true)
    }
    
    @Test("refreshTokens(using:) falls back to existing refresh token when backend omits it")
    func refreshKeepsOldToken() async throws {
        var json = tokenResponse()
        json["refresh_token"] = nil
        
        let repo  = makeRepository(json: json)
        let auth  = try await repo.refreshTokens(using: "refresh-OLD")
        
        #expect(auth.refreshToken == "refresh-OLD")
    }
}
