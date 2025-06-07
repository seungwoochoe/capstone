//
//  WebRepositoryTests.swift
//  CapstoneTests
//
//  Created by Seungwoo Choe on 2025-06-07.
//

import Foundation
import Testing
@testable import Capstone

@Suite("WebRepositoryTests", .serialized)
struct WebRepositoryTests {
    
    struct DummyModel: Codable, Equatable {
        let name: String
    }

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
        let expected = DummyModel(name: "Alice")
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
