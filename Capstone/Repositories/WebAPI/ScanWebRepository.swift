//
//  ScanWebRepository.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import Foundation

// MARK: - DTOs

/// Response returned by POST /scans – delivers the server‑side job identifier
struct UploadResponse: Decodable {
    let id: String
}

/// Response returned by GET /scans/{id}
struct ScanResponse: Decodable {
    let id: String
    let name: String
    let usdzURL: URL
    let processedAt: Date
    let status: String
}

// MARK: - Protocol

protocol ScanWebRepository: WebRepository {
    func uploadScan(name: String, images: [Data]) async throws -> UploadResponse
    func fetchScan(id: String) async throws -> ScanResponse
    func downloadUSDZ(from url: URL) async throws -> URL
}

// MARK: - RealScanWebRepository

struct RealScanWebRepository: ScanWebRepository {

    let session: URLSession
    let baseURL: String

    init(session: URLSession = .shared, baseURL: String) {
        self.session = session
        self.baseURL = baseURL
    }

    func uploadScan(name: String, images: [Data]) async throws -> UploadResponse {
        let multipart = try MultipartForm.Builder()
            .append(name, named: "name")
            .append(images,
                    named: "files[]",
                    mimeType: "image/jpeg",
                    filenamePrefix: "image",
                    fileExtension: "jpg")
            .build()

        return try await call(endpoint: API.UploadScan(payload: multipart))
    }

    func fetchScan(id: String) async throws -> ScanResponse {
        try await call(endpoint: API.ScanDetail(id: id))
    }

    func downloadUSDZ(from url: URL) async throws -> URL {
        let (tmpURL, _) = try await session.download(from: url)
        let dst = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.removeItem(at: dst)
        try FileManager.default.moveItem(at: tmpURL, to: dst)
        return dst
    }
}

// MARK: - Private Endpoint definitions

private extension RealScanWebRepository {

    enum API {
        /// POST /scans – multipart
        struct UploadScan: APICall {
            let payload: MultipartPayload

            var path: String { "/scans" }
            var method: String { "POST" }
            var headers: [String : String]? {
                ["Content-Type": payload.contentType]
            }
            func body() throws -> Data? { payload.data }
        }

        /// GET /scans/{id}
        struct ScanDetail: APICall {
            let id: String
            var path: String { "/scans/\(id)" }
            var method: String { "GET" }
            var headers: [String : String]? { nil }
            func body() throws -> Data? { nil }
        }
    }
}
