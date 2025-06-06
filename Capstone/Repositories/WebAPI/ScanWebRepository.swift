//
//  ScanWebRepository.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import Foundation

struct PresignedURLsResponse: Decodable {
    let presigned: [URL]
}

struct TaskStatusResponse: Decodable {
    let id: String
    let status: String               // "pending-upload" | "ready-for-processing" | "finished" | "failed"
    let usdzURL: URL?                // present only when status == "finished"
    let processedAt: Date?           // optional ISO-8601 timestamp
    
    enum CodingKeys: String, CodingKey {
        case id, status, usdzURL = "usdzUrl", processedAt
    }
}

struct OKResponse: Decodable { let ok: Bool }

// MARK: - ScanWebRepository

protocol ScanWebRepository: WebRepository {
    func uploadScan(id: String, images: [Data]) async throws -> Bool
    func fetchTask(id: String) async throws -> TaskStatusResponse
    func downloadUSDZ(from url: URL) async throws -> URL
}

// MARK: - RealScanWebRepository

struct RealScanWebRepository: ScanWebRepository {
    
    let session: URLSession
    let baseURL: String
    let tokenProvider: AccessTokenProvider
    
    init(session: URLSession = .shared, baseURL: String, accessTokenProvider: AccessTokenProvider) {
        self.session = session
        self.baseURL = baseURL
        self.tokenProvider = accessTokenProvider
    }
    
    func uploadScan(id: String, images: [Data]) async throws -> Bool {
        // STEP 1
        let presignedResponse: PresignedURLsResponse = try await call(
            endpoint: API.CreateUploadUrls(taskID: id, count: images.count)
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
        guard let endpointArn = Defaults[.pushEndpointArn] else {
            throw APIError.unexpectedResponse
        }
        
        let okResponse: OKResponse = try await call(
            endpoint: API.UploadComplete(taskID: id, endpointArn: endpointArn)
        )
        
        return okResponse.ok
    }
    
    func fetchTask(id: String) async throws -> TaskStatusResponse {
        try await call(endpoint: API.TaskDetail(id: id))
    }
    
    func downloadUSDZ(from url: URL) async throws -> URL {
        let (tmpURL, _) = try await session.download(from: url)
        let dst = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.removeItem(at: dst)
        try FileManager.default.moveItem(at: tmpURL, to: dst)
        return dst
    }
}

// MARK: - Endpoint definitions

private extension RealScanWebRepository {
    
    enum API {
        
        // 1) POST /upload-urls
        struct CreateUploadUrls: APICall, Encodable {
            let taskId: String
            let imageCount: Int
            
            init(taskID: String, count: Int) {
                self.taskId = taskID
                self.imageCount = count
            }
            
            var path: String { "/upload-urls" }
            var method: String { "POST" }
            var headers: [String : String]? { ["Content-Type": "application/json"] }
            func body() throws -> Data? { try JSONEncoder().encode(self) }
        }
        
        // 2) POST /tasks/{id}/complete
        struct UploadComplete: APICall {
            let taskID: String
            let endpointArn: String
            
            var path: String { "/tasks/\(taskID)/complete" }
            var method: String { "POST" }
            var headers: [String : String]? { ["Content-Type": "application/json"] }
            
            func body() throws -> Data? {
                // We send { "snsEndpointArn": "<endpointArn>" }
                let payload: [String: String] = ["snsEndpointArn": endpointArn]
                return try JSONEncoder().encode(payload)
            }
        }
        
        // 3) GET /tasks/{id}
        struct TaskDetail: APICall {
            let id: String
            var path: String { "/tasks/\(id)" }
            var method: String { "GET" }
            var headers: [String : String]? { nil }
            func body() throws -> Data? { nil }
        }
    }
}
