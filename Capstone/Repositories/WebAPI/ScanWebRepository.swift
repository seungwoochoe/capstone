//
//  ScanWebRepository.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import Foundation

struct ScanUploadResponse: Codable, Equatable {
    let taskID: String
    let status: String
    let message: String?
}

struct ScanResponse: Codable, Equatable {
    let scanID: String
    let scanName: String
    let usdzURL: URL
    let processedDate: Date
}

protocol ScanWebRepository: WebRepository {
    func uploadScan(scanName: String, imageData: [Data]) async throws -> ScanUploadResponse
    func scanDetails(for scanID: String) async throws -> ScanResponse
    func fetchScans() async throws -> [ScanResponse]
}

struct RealScanWebRepository: ScanWebRepository {
    let session: URLSession
    let baseURL: String = "https://your-server.com/api/scans"

    func uploadScan(scanName: String, imageData: [Data]) async throws -> ScanUploadResponse {
        return try await call(endpoint: API.uploadScan(name: scanName, imageData: imageData))
    }
    
    func scanDetails(for scanID: String) async throws -> ScanResponse {
        return try await call(endpoint: API.scanDetails(scanID: scanID))
    }
    
    func fetchScans() async throws -> [ScanResponse] {
        return try await call(endpoint: API.allScans)
    }
}

extension RealScanWebRepository {
    enum API {
        case uploadScan(name: String, imageData: [Data])
        case scanDetails(scanID: String)
        case allScans
    }
}

extension RealScanWebRepository.API: APICall {
    var path: String {
        switch self {
        case .uploadScan:
            return "/upload"
        case let .scanDetails(scanID):
            return "/\(scanID)"
        case .allScans:
            return "/list"
        }
    }
    
    var method: String {
        switch self {
        case .uploadScan: return "POST"
        case .scanDetails, .allScans: return "GET"
        }
    }
    
    var headers: [String: String]? {
        ["Content-Type": "application/json", "Accept": "application/json"]
    }
    
    func body() throws -> Data? {
        switch self {
        case let .uploadScan(name, imageData):
            // This assumes a JSON payload:
            let payload: [String: Any] = [
                "name": name,
                // Encode the images appropriately (base64, or pass them as form-data).
                "images": imageData.map { $0.base64EncodedString() }
            ]
            return try JSONSerialization.data(withJSONObject: payload, options: [])
        default:
            return nil
        }
    }
}
