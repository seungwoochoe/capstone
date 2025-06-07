//
//  ScanWebRepository.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import Foundation

struct PresignedURLsResponse: Codable {
    let presigned: [URL]
}

struct TaskStatusResponse: Codable, Equatable {
    let status: String               // "pending-upload" | "ready-for-processing" | "finished" | "failed"
    let usdzURL: URL?                // present only when status == "finished"
    let processedAt: Date?           // optional ISO-8601 timestamp
    
    enum CodingKeys: String, CodingKey {
        case status, usdzURL = "usdzUrl", processedAt
    }
}

struct OKResponse: Decodable { let ok: Bool }

enum DownloadError: Error {
    case documentsDirectoryUnavailable
    case invalidStatus(code: Int?, body: String)
}

// MARK: - ScanWebRepository

protocol ScanWebRepository: WebRepository {
    func uploadScan(id: String, images: [Data]) async throws -> Bool
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
    
    func uploadScan(id: String, images: [Data]) async throws -> Bool {
        // STEP 1
        let presignedResponse: PresignedURLsResponse = try await call(
            endpoint: API.CreateUploadUrls(scanID: id, count: images.count)
        )
        let presigned = presignedResponse.presigned
        
        guard presigned.count == images.count else {
            throw APIError.unexpectedResponse
        }
        
        // STEP 2
        try await withThrowingTaskGroup(of: Void.self) { group in
            for (idx, url) in presigned.enumerated() {
                let data = images[idx]
                group.addTask {
                    var req = URLRequest(url: url)
                    req.httpMethod = "PUT"
                    req.addValue("image/jpeg", forHTTPHeaderField: "Content-Type")
                    _ = try await session.upload(for: req, from: data).1
                }
            }
            try await group.waitForAll()
        }
        
        // STEP 3
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
        try fileManager.createDirectory(
            at: scanDir,
            withIntermediateDirectories: true
        )
        
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
        
        // 1) POST /upload-urls
        struct CreateUploadUrls: APICall, Encodable {
            let scanID: String
            let imageCount: Int
            
            init(scanID: String, count: Int) {
                self.scanID = scanID
                self.imageCount = count
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
                // We send { "snsEndpointArn": "<endpointArn>" }
                let payload: [String: String] = ["snsEndpointArn": endpointArn]
                return try JSONEncoder().encode(payload)
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
