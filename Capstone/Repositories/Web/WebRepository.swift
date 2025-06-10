//
//  WebRepository.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-11.
//

import Foundation
import Combine
import OSLog

private let logger = Logger.forType(WebRepository.self)

protocol WebRepository {
    var session: URLSession { get }
    var baseURL: String { get }
    var tokenProvider: AccessTokenProvider { get }
}

extension WebRepository {
    
    private func authorizationHeader() async throws -> String {
        let token = try await tokenProvider.validAccessToken()
        return "Bearer \(token)"
    }
    
    func call<Value, Decoder>(
        endpoint: APICall,
        decoder: Decoder = JSONDecoder(),
        httpCodes: HTTPCodes = .success
    ) async throws -> Value
    where Value: Decodable, Decoder: TopLevelDecoder, Decoder.Input == Data {
        
        var request = try endpoint.urlRequest(baseURL: baseURL)
        let bearer = try await authorizationHeader()
        request.setValue(bearer, forHTTPHeaderField: "Authorization")
        
        logger.debug("Sending request to URL: \(request.url?.absoluteString ?? "<invalid URL>").")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Unexpected response type: \(type(of: response)).")
                throw APIError.unexpectedResponse
            }
            
            let code = httpResponse.statusCode
            logger.debug("Received response with status code: \(code).")
            
            guard httpCodes.contains(code) else {
                logger.error("Unexpected HTTP status code: \(code). Expected: \(httpCodes).")
                throw APIError.httpCode(code)
            }
            
            do {
                let result = try decoder.decode(Value.self, from: data)
                logger.debug("Decoded response as type: \(Value.self).")
                return result
            } catch {
                let body = String(data: data, encoding: .utf8) ?? "<non-textual data>"
                logger.error("Decoding failed. Error: \(error). Body: \(body, privacy: .public).")
                throw APIError.unexpectedResponse
            }
            
        } catch {
            logger.error("Network request failed. Error: \(error).")
            throw error
        }
    }
}

// MARK: - APICall

typealias HTTPCode = Int
typealias HTTPCodes = Range<HTTPCode>

extension HTTPCodes {
    static let success = 200 ..< 300
}

protocol APICall {
    var path: String { get }
    var method: String { get }
    var headers: [String: String]? { get }
    func body() throws -> Data?
}

extension APICall {
    func urlRequest(baseURL: String) throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.allHTTPHeaderFields = headers
        request.httpBody = try body()
        return request
    }
}

enum APIError: Swift.Error, Equatable, LocalizedError {
    case invalidURL
    case notSignedIn
    case httpCode(HTTPCode)
    case unexpectedResponse
    case imageDeserialization
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .notSignedIn: return "User is not signed in"
        case let .httpCode(code): return "Unexpected HTTP code: \(code)"
        case .unexpectedResponse: return "Unexpected response from the server"
        case .imageDeserialization: return "Cannot deserialize image from Data"
        }
    }
}
