//
//  WebRepositoryTests.swift
//  CapstoneTests
//
//  Created by Seungwoo Choe on 2025-05-14.
//

import Foundation
import Testing
@testable import Capstone

// MARK: — Helpers for tests

/// A simple Codable model to round-trip in tests.
struct TestModel: Codable, Equatable {
    let id: Int
    let name: String
}

/// A minimal APICall implementation so we can drive `urlRequest(baseURL:)`
struct TestAPICall: APICall {
    let path: String
    let method: String
    let headers: [String: String]?
    let bodyData: Data?
    
    func body() throws -> Data? {
        return bodyData
    }
}

// MARK: — Test Suite

@Suite("WebRepository.call and urlRequest(baseURL:) Tests", .serialized)
struct WebRepositoryTests {
    // Use the test‐only repository that embeds our mocked session
    let repository = TestWebRepository()
    
    // Clear any leftover mocks before each test
    init() {
        RequestMocking.removeAllMocks()
    }
    
    @Test("urlRequest constructs URLRequest correctly")
    func urlRequestConstruction() throws {
        let call = TestAPICall(
            path: "/foo",
            method: "POST",
            headers: ["X-Test": "Value"],
            bodyData: Data("hello".utf8)
        )
        let request = try call.urlRequest(baseURL: repository.baseURL)
        
        #expect(request.url?.absoluteString == repository.baseURL + "/foo")
        #expect(request.httpMethod == "POST")
        #expect(request.allHTTPHeaderFields == ["X-Test": "Value"])
        #expect(request.httpBody == Data("hello".utf8))
    }
    
    @Test("Successful call returns decoded model")
    func successfulCall() async throws {
        let expected = TestModel(id: 42, name: "Arthur")
        let call = TestAPICall(path: "/model", method: "GET", headers: nil, bodyData: nil)
        
        // Arrange: mock a 200 OK + JSON body
        try RequestMocking.add(
            mock: RequestMocking.MockedResponse(
                apiCall: call,
                baseURL: repository.baseURL,
                result: .success(expected)
            )
        )
        
        // Act
        let result: TestModel = try await repository.call(endpoint: call)
        
        // Assert
        #expect(result == expected)
    }
    
    @Test("call throws .httpCode when status code is not in 200..<300")
    func throwsHttpCode() async throws {
        let call = TestAPICall(path: "/notfound", method: "GET", headers: nil, bodyData: nil)
        
        // Arrange: mock a 404 Not Found
        try RequestMocking.add(
            mock: RequestMocking.MockedResponse(
                apiCall: call,
                baseURL: repository.baseURL,
                result: .success(TestModel(id: 0, name: "")),
                httpCode: 404
            )
        )
        
        // Act & Assert
        do {
            _ = try await repository.call(endpoint: call) as TestModel
            #expect(Bool(false))  // we should never reach here
        } catch let error as APIError {
            #expect(error == .httpCode(404))
        } catch {
            #expect(Bool(false))  // wrong error type
        }
    }
    
    @Test("call throws .unexpectedResponse for non-HTTPURLResponse")
    func throwsOnNonHTTPResponse() async throws {
        let call = TestAPICall(path: "/none", method: "GET", headers: nil, bodyData: nil)
        let url = URL(string: repository.baseURL + "/none")!
        let customResponse = URLResponse(
            url: url,
            mimeType: nil,
            expectedContentLength: 0,
            textEncodingName: nil
        )
        
        // Arrange: mock a non-HTTP URLResponse
        try RequestMocking.add(
            mock: RequestMocking.MockedResponse(
                apiCall: call,
                baseURL: repository.baseURL,
                customResponse: customResponse
            )
        )
        
        // Act & Assert
        do {
            _ = try await repository.call(endpoint: call) as TestModel
            #expect(Bool(false))
        } catch let error as APIError {
            #expect(error == .unexpectedResponse)
        } catch {
            print(error)
            #expect(Bool(false))
        }
    }
    
    @Test("call throws .unexpectedResponse on JSON decoding failure")
    func throwsOnDecodingFailure() async throws {
        let call = TestAPICall(path: "/badjson", method: "GET", headers: nil, bodyData: nil)
        let badData = Data("not a json".utf8)
        
        // Arrange: mock a 200 OK with invalid JSON
        try RequestMocking.add(
            mock: RequestMocking.MockedResponse(
                apiCall: call,
                baseURL: repository.baseURL,
                result: .success(badData)
            )
        )
        
        // Act & Assert
        do {
            _ = try await repository.call(endpoint: call) as TestModel
            #expect(Bool(false))
        } catch let error as APIError {
            #expect(error == .unexpectedResponse)
        } catch {
            print(error)
            #expect(Bool(false))
        }
    }
}
