//
//  TestHelpers.swift
//  CapstoneTests
//
//  Created by Seungwoo Choe on 2025-05-17.
//

import Foundation

enum MockError: Swift.Error {
    case valueNotSet
}

// MARK: - URLProtocol stub used by all tests

final class MockURLProtocol: URLProtocol {
    
    typealias Response = (HTTPURLResponse, Data)
    static var handler: (URLRequest) throws -> Response = { _ in fatalError("Handler not set") }
    
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    
    override func startLoading() {
        do {
            let (response, data) = try Self.handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    
    override func stopLoading() {}
}

// MARK: - Small helper to make JWT fragments readable

extension Data {
    /// Base64-URL encodes without `=`, `+`, `/`
    func base64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
