//
//  ModelDownloadRepository.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-11.
//

import Foundation

protocol ModelDownloadRepository: WebRepository {
    func downloadUSDZ(from url: URL) async throws -> Data
}

struct RealModelDownloadRepository: ModelDownloadRepository {
    let session: URLSession
    // baseURL might not be required.
    let baseURL: String = ""

    func downloadUSDZ(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.unexpectedResponse
        }
        return data
    }
}
