//
//  ScanWebRepository.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import Foundation
import OSLog

struct PresignedURLsResponse: Codable {
    let presigned: [URL]
}

struct TaskStatusResponse: Codable, Equatable {
    let status: String     // "pending-upload" | "ready-for-processing" | "finished" | "failed"
    let modelURL: URL?
    let createdAt: Date?   // ISO-8601 timestamp
    
    enum CodingKeys: String, CodingKey {
        case status, modelURL = "modelUrl", createdAt
    }
}

struct OKResponse: Decodable { let ok: Bool }

enum DownloadError: Error {
    case documentsDirectoryUnavailable
    case invalidStatus(code: Int?, body: String)
}

// MARK: - ScanWebRepository

protocol ScanWebRepository: WebRepository {
    func uploadScan(id: String, file: Data) async throws -> Bool
    func fetchTask(id: String) async throws -> TaskStatusResponse
    func downloadUSDZ(from url: URL, scanID: String) async throws
}

// MARK: - RealScanWebRepository

struct RealScanWebRepository: ScanWebRepository {
    
    let session: URLSession
    let baseURL: String
    let tokenProvider: AccessTokenProvider
    let defaultsService: DefaultsService
    let fileManager: FileManager
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: #file)
    
    init(session: URLSession = .shared,
         baseURL: String,
         accessTokenProvider: AccessTokenProvider,
         defaultsService: DefaultsService,
         fileManager: FileManager
    ) {
        self.session = session
        self.baseURL = baseURL
        self.tokenProvider = accessTokenProvider
        self.defaultsService = defaultsService
        self.fileManager = fileManager
    }
    
    func uploadScan(id: String, file: Data) async throws -> Bool {
        // STEP 1: ask backend for a presigned-URL
        let presignedResponse: PresignedURLsResponse = try await call(
            endpoint: API.CreateUploadUrls(scanID: id, fileCount: 1)
        )
        guard let uploadURL = presignedResponse.presigned.first else {
            throw APIError.unexpectedResponse
        }
        
        // STEP 2: PUT the binary file to S3
        var req = URLRequest(url: uploadURL)
        req.httpMethod = "PUT"
        req.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        logger.debug("Uploading to S3 via presigned URL")
        let (data, uploadResp) = try await session.upload(for: req, from: file)
        
        if let httpResponse = uploadResp as? HTTPURLResponse {
            if HTTPCodes.success.contains(httpResponse.statusCode) {
                logger.info("S3 PUT finished with status code: \(httpResponse.statusCode)")
            } else {
                let body = String(data: data, encoding: .utf8) ?? "<non-textual data>"
                logger.error("S3 upload failed with status code: \(httpResponse.statusCode), body: \(body, privacy: .public)")
                throw APIError.httpCode(httpResponse.statusCode)
            }
        } else {
            logger.error("S3 PUT finished but couldn’t read HTTP status")
            throw APIError.unexpectedResponse
        }
        
        logger.debug("Calling UploadComplete…")
        
        // STEP 3: notify backend that upload is complete so processing can begin
        guard let endpointArn = defaultsService[.pushEndpointArn] else {
            throw APIError.unexpectedResponse
        }
        
        let okResponse: OKResponse = try await call(
            endpoint: API.UploadComplete(scanID: id, endpointArn: endpointArn)
        )
        return okResponse.ok
    }
    
    func fetchTask(id: String) async throws -> TaskStatusResponse {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try await call(
            endpoint: API.TaskDetail(id: id),
            decoder: decoder
        )
    }
    
    func downloadUSDZ(from url: URL, scanID: String) async throws {
        let (tmpURL, response) = try await session.download(from: url)
        
        guard
            let httpURLResponse = response as? HTTPURLResponse,
            HTTPCodes.success.contains(httpURLResponse.statusCode)
        else {
            let body = try? String(contentsOf: tmpURL, encoding: .utf8)
            throw DownloadError.invalidStatus(code: (response as? HTTPURLResponse)?.statusCode,
                                              body: body ?? "<unreadable>")
        }
        
        let docsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let scanDir = docsDir.appendingPathComponent(scanID)
        try fileManager.createDirectory(at: scanDir, withIntermediateDirectories: true)
        
        let destURL = scanDir.appendingPathComponent(url.lastPathComponent)
        if fileManager.fileExists(atPath: destURL.path) {
            try fileManager.removeItem(at: destURL)
        }
        try fileManager.moveItem(at: tmpURL, to: destURL)
    }
}

// MARK: - Endpoint definitions

private extension RealScanWebRepository {
    
    enum API {
        
        // 1) POST /upload-urls  – ask for 1 presigned URL
        struct CreateUploadUrls: APICall, Encodable {
            let scanID: String
            let fileCount: Int
            
            init(scanID: String, fileCount: Int) {
                self.scanID   = scanID
                self.fileCount = fileCount
            }
            
            var path: String { "/upload-urls" }
            var method: String { "POST" }
            var headers: [String : String]? { ["Content-Type": "application/json"] }
            func body() throws -> Data? { try JSONEncoder().encode(self) }
        }
        
        // 2) POST /scans/{id}/complete
        struct UploadComplete: APICall {
            let scanID: String
            let endpointArn: String
            
            var path: String { "/scans/\(scanID)/complete" }
            var method: String { "POST" }
            var headers: [String : String]? { ["Content-Type": "application/json"] }
            func body() throws -> Data? {
                try JSONEncoder().encode(["snsEndpointArn": endpointArn])
            }
        }
        
        // 3) GET /scans/{id}
        struct TaskDetail: APICall {
            let id: String
            var path: String { "/scans/\(id)" }
            var method: String { "GET" }
            var headers: [String : String]? { nil }
            func body() throws -> Data? { nil }
        }
    }
}
