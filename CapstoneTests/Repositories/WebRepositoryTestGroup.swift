//
//  WebRepositoryTests.swift
//  CapstoneTests
//
//  Created by Seungwoo Choe on 2025-06-07.
//

import Foundation
import Testing
@testable import Capstone

@Suite("WebRepositoryTestGroup", .serialized)
struct WebRepositoryTestGroup {
    
    // MARK: - WebRepositoryTests
    
    @Suite("WebRepositoryTests", .serialized)
    struct WebRepositoryTests {
        
        struct DummyModel: Codable, Equatable {}
        
        struct DummyCall: APICall {
            let path: String
            let method: String
            let headers: [String: String]?
            let bodyData: Data?
            
            init(path: String = "/dummy", method: String = "GET", headers: [String: String]? = nil, body: Data? = nil) {
                self.path = path
                self.method = method
                self.headers = headers
                self.bodyData = body
            }
            
            func body() throws -> Data? {
                return bodyData
            }
        }
        
        struct StubWebRepository: WebRepository {
            let session: URLSession
            let baseURL: String
            let tokenProvider: AccessTokenProvider
        }
        
        private func makeRepo(handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) -> StubWebRepository {
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [MockURLProtocol.self]
            let session = URLSession(configuration: config)
            MockURLProtocol.handler = handler
            let tokenProvider = StubAccessTokenProvider(token: "TEST_TOKEN")
            return StubWebRepository(session: session, baseURL: "https://api.test", tokenProvider: tokenProvider)
        }
        
        @Test("Successful call returns decoded model")
        func testCallSuccess() async throws {
            let expected = DummyModel()
            let data = try JSONEncoder().encode(expected)
            let httpResponse = HTTPURLResponse(
                url: URL(string: "https://api.test/dummy")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            
            let repo = makeRepo { request in
                // Verify Authorization header
                #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer TEST_TOKEN")
                return (httpResponse, data)
            }
            
            let result: DummyModel = try await repo.call(endpoint: DummyCall())
            #expect(result == expected)
        }
        
        @Test("HTTP error code throws APIError.httpCode")
        func testCallHTTPError() async throws {
            let httpResponse = HTTPURLResponse(
                url: URL(string: "https://api.test/dummy")!,
                statusCode: 404,
                httpVersion: nil,
                headerFields: nil
            )!
            let repo = makeRepo { request in
                return (httpResponse, Data())
            }
            
            do {
                let _: DummyModel = try await repo.call(endpoint: DummyCall())
                #expect(Bool(false), "Expected httpCode error, but call succeeded.")
            } catch let APIError.httpCode(code) {
                #expect(code == 404)
            } catch {
                #expect(Bool(false), "Unexpected error: \(error)")
            }
        }
        
        @Test("Decoding failure throws APIError.unexpectedResponse")
        func testCallDecodingError() async throws {
            let invalidJSON = Data("{ invalid json }".utf8)
            let httpResponse = HTTPURLResponse(
                url: URL(string: "https://api.test/dummy")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let repo = makeRepo { request in
                return (httpResponse, invalidJSON)
            }
            
            do {
                let _: DummyModel = try await repo.call(endpoint: DummyCall())
                #expect(Bool(false), "Expected decoding error, but call succeeded.")
            } catch APIError.unexpectedResponse {
                #expect(true)
            } catch {
                #expect(Bool(false), "Unexpected error: \(error)")
            }
        }
        
        @Test("Invalid URL in endpoint throws APIError.invalidURL")
        func testInvalidURLError() async throws {
            let badCall = DummyCall(path: ":://bad_url")
            let repo = makeRepo { _ in
                #expect(Bool(false), "Network should not be called on invalid URL")
                return (HTTPURLResponse(), Data())
            }
            
            do {
                let _: DummyModel = try await repo.call(endpoint: badCall)
                #expect(Bool(false), "Expected invalidURL error, but call succeeded.")
            } catch APIError.invalidURL {
                #expect(true)
            } catch {
                #expect(Bool(false), "Unexpected error: \(error)")
            }
        }
    }
    
    @Suite("AuthenticationWebRepositoryTests", .serialized)
    struct AuthenticationWebRepositoryTests {
        
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
    
    // MARK: - PushTokenWebRepositoryTests
    
    @Suite("PushTokenWebRepositoryTests", .serialized)
    struct PushTokenWebRepositoryTests {
        
        private func makeRepository(
            handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
        ) -> RealPushTokenWebRepository {
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [MockURLProtocol.self]
            let session = URLSession(configuration: config)
            MockURLProtocol.handler = handler
            return RealPushTokenWebRepository(
                session: session,
                baseURL: "https://api.test",
                accessTokenProvider: StubAccessTokenProvider(token: "TEST_TOKEN")
            )
        }
        
        private func bodyData(from request: URLRequest) throws -> Data {
            if let data = request.httpBody { return data }
            guard let stream = request.httpBodyStream else { return Data() }
            stream.open(); defer { stream.close() }
            var buffer = Data()
            let size = 1024
            let ptr   = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
            defer { ptr.deallocate() }
            while stream.hasBytesAvailable {
                let read = stream.read(ptr, maxLength: size)
                guard read > 0 else { break }
                buffer.append(ptr, count: read)
            }
            return buffer
        }
        
        private func http200(_ req: URLRequest) -> HTTPURLResponse {
            HTTPURLResponse(
                url: req.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
        }
        
        // MARK: - Tests
        
        @Test("registerPushToken sends correct request and returns endpointArn")
        func registerPushTokenSuccess() async throws {
            // Given
            let expectedArn  = "arn:aws:sns:us-east-1:123456789012:endpoint/APNS/my-app/abcdef123456"
            let responseData = try JSONEncoder().encode(RegisterPushTokenResponse(endpointArn: expectedArn))
            
            let tokenBytes: [UInt8] = [0xDE, 0xAD, 0xBE, 0xEF]
            let tokenData           = Data(tokenBytes)
            let expectedHex         = tokenBytes.map { String(format: "%02x", $0) }.joined()
            
            let repo = makeRepository { req in
                // HTTP method & path
                #expect(req.httpMethod == "POST")
                #expect(req.url!.path == "/devices/push-token")
                
                // Headers
                #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer TEST_TOKEN")
                #expect(req.value(forHTTPHeaderField: "Content-Type") == "application/json")
                
                // Body JSON with correct hex token
                let body = try self.bodyData(from: req)
                let json = try JSONSerialization.jsonObject(with: body, options: []) as? [String: Any]
                #expect(json?["token"] as? String == expectedHex)
                
                return (self.http200(req), responseData)
            }
            
            let arn = try await repo.registerPushToken(tokenData)
            #expect(arn == expectedArn)
        }
        
        @Test("registerPushToken propagates HTTP errors as APIError.httpCode")
        func registerPushTokenHTTPError() async throws {
            // Intercept and return 500 error
            let repo = makeRepository { req in
                let resp = HTTPURLResponse(
                    url: req.url!,
                    statusCode: 500,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (resp, Data())
            }
            
            do {
                _ = try await repo.registerPushToken(Data("oops".utf8))
                #expect(Bool(false), "Expected httpCode error but call succeeded")
            } catch let APIError.httpCode(code) {
                #expect(code == 500)
            } catch {
                #expect(Bool(false), "Unexpected error: \(error)")
            }
        }
        
        @Test("registerPushToken throws APIError.unexpectedResponse on decoding failure")
        func registerPushTokenDecodingError() async throws {
            // Backend returns invalid JSON (missing endpointArn)
            let invalidJSON = Data("{ \"foo\": \"bar\" }".utf8)
            
            let repo = makeRepository { req in
                return (self.http200(req), invalidJSON)
            }
            
            do {
                _ = try await repo.registerPushToken(Data("1234".utf8))
                #expect(Bool(false), "Expected unexpectedResponse but call succeeded")
            } catch APIError.unexpectedResponse {
                #expect(true)
            } catch {
                #expect(Bool(false), "Unexpected error: \(error)")
            }
        }
    }
    
    // MARK: - ScanWebRepositoryTests
    
    @Suite("ScanWebRepositoryTests", .serialized)
    struct ScanWebRepositoryTests {
        private let fileManager = FileManager.default
        
        private func http200(_ req: URLRequest,
                             mime: String = "application/json") -> HTTPURLResponse {
            HTTPURLResponse(url: req.url!,
                            statusCode: 200,
                            httpVersion: nil,
                            headerFields: ["Content-Type": mime])!
        }
        
        private func makeRepository(
            defaults: StubDefaultsService = .init(),
            handler: @escaping (URLRequest) throws -> MockURLProtocol.Response
        ) -> RealScanWebRepository {
            
            MockURLProtocol.handler = handler
            
            let cfg = URLSessionConfiguration.ephemeral
            cfg.protocolClasses = [MockURLProtocol.self]
            
            return RealScanWebRepository(
                session: URLSession(configuration: cfg),
                baseURL: "https://api.example.com",
                accessTokenProvider: StubAccessTokenProvider(token: "token-123"),
                defaultsService: defaults,
                fileManager: fileManager
            )
        }
        
        // Tests
        
        @Test("upload succeeds")
        func uploadSuccess() async throws {
            let fileData = Data("file-content".utf8)
            let presignedURL = URL(string: "https://presigned.example.com/upload")!
            let presignedResponse = PresignedURLsResponse(presigned: [presignedURL])
            let presignedData = try JSONEncoder().encode(presignedResponse)
            let okData = #"{"ok":true}"#.data(using: .utf8)!
            
            var requests: [URLRequest] = []
            let defaults = StubDefaultsService()
            defaults[.pushEndpointArn] = "arn:aws:sns:…/endpoint"
            
            let repo = makeRepository(defaults: defaults) { req in
                requests.append(req)
                switch (req.httpMethod, req.url!.path) {
                case ("POST", "/upload-urls"):
                    // Authorization header
                    #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer token-123")
                    // JSON body keys: scanID and fileCount
                    if let body = req.httpBody,
                       let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
                        #expect(json["scanID"] as? String == "scan-1")
                        #expect(json["fileCount"] as? Int == 1)
                    }
                    return (http200(req), presignedData)
                    
                case ("PUT", _):
                    // Content-Type is application/octet-stream
                    #expect(req.value(forHTTPHeaderField: "Content-Type") == "application/octet-stream")
                    return (http200(req, mime: "text/plain"), Data())
                    
                case ("POST", let path) where path.hasSuffix("/complete"):
                    #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer token-123")
                    return (http200(req), okData)
                    
                default:
                    throw MockError.valueNotSet
                }
            }
            
            let ok = try await repo.upload(id: "scan-1", file: fileData)
            #expect(ok)
            #expect(requests.count == 3)
        }
        
        @Test("upload throws when no presigned URL returned")
        func uploadNoPresignedURL() async throws {
            let fileData = Data("empty".utf8)
            let emptyResponse = PresignedURLsResponse(presigned: [])
            let data = try JSONEncoder().encode(emptyResponse)
            
            let defaults = StubDefaultsService()
            defaults[.pushEndpointArn] = "arn:aws:sns:…/endpoint"
            
            let repo = makeRepository(defaults: defaults) { req in
                guard req.url!.path == "/upload-urls" else {
                    throw MockError.valueNotSet
                }
                return (http200(req), data)
            }
            
            do {
                _ = try await repo.upload(id: "scan-x", file: fileData)
                #expect(Bool(false), "Expected to throw when no presigned URL")
            } catch let err as APIError {
                #expect(err == .unexpectedResponse)
            }
        }
        
        @Test("upload throws when pushEndpointArn missing")
        func uploadMissingEndpointArn() async throws {
            let fileData = Data("data".utf8)
            let presignedURL = URL(string: "https://presigned.example.com/upload")!
            let presignedResponse = PresignedURLsResponse(presigned: [presignedURL])
            let data = try JSONEncoder().encode(presignedResponse)
            
            let repo = makeRepository { req in
                switch (req.httpMethod, req.url!.path) {
                case ("POST", "/upload-urls"):
                    return (http200(req), data)
                case ("PUT", _):
                    return (http200(req, mime: "application/octet-stream"), Data())
                default:
                    throw MockError.valueNotSet
                }
            }
            
            do {
                _ = try await repo.upload(id: "scan-no-arn", file: fileData)
                #expect(Bool(false), "Expected to throw when endpoint ARN missing")
            } catch let err as APIError {
                #expect(err == .unexpectedResponse)
            }
        }
        
        @Test("fetchTask decodes correctly")
        func fetchTask() async throws {
            let expected = TaskStatusResponse(status: "pending-upload",
                                              modelURL: nil,
                                              createdAt: nil)
            let data = try JSONEncoder().encode(expected)
            
            let repo = makeRepository { req in
                #expect(req.httpMethod == "GET")
                #expect(req.url!.path == "/scans/abc")
                return (http200(req), data)
            }
            
            let result = try await repo.fetchTask(id: "abc")
            #expect(result == expected)
        }
        
        @Test("downloadModel writes file to Documents directory")
        func downloadModelWritesFile() async throws {
            let modelData = Data("dummy-model".utf8)
            let remoteURL = URL(string: "https://presigned.example.com/model.usdz")!
            let scanID = UUID().uuidString
            
            let repo = makeRepository { req in
                #expect(req.url == remoteURL)
                return (http200(req, mime: "model/vnd.usdz+zip"), modelData)
            }
            
            try await repo.downloadModel(from: remoteURL, scanID: scanID)
            
            let docsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let destURL = docsDir
                .appendingPathComponent(scanID)
                .appendingPathComponent(remoteURL.lastPathComponent)
            
            #expect(fileManager.fileExists(atPath: destURL.path))
            #expect(try Data(contentsOf: destURL) == modelData)
            #expect(destURL.lastPathComponent == "model.usdz")
        }
    }
}
