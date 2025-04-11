//
//  ScannedRoomWebRepository.swift
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

struct ScannedRoomResponse: Codable, Equatable {
    let roomID: String
    let roomName: String
    let usdzURL: URL
    let processedDate: Date
}

protocol ScannedRoomWebRepository: WebRepository {
    func uploadScan(roomName: String, imageData: [Data]) async throws -> ScanUploadResponse
    func scannedRoomDetails(for roomID: String) async throws -> ScannedRoomResponse
    func fetchScannedRooms() async throws -> [ScannedRoomResponse]
}

struct RealScannedRoomWebRepository: ScannedRoomWebRepository {
    let session: URLSession
    let baseURL: String = "https://your-server.com/api/rooms"

    func uploadScan(roomName: String, imageData: [Data]) async throws -> ScanUploadResponse {
        return try await call(endpoint: API.uploadScan(roomName: roomName, imageData: imageData))
    }
    
    func scannedRoomDetails(for roomID: String) async throws -> ScannedRoomResponse {
        return try await call(endpoint: API.scannedRoomDetails(roomID: roomID))
    }
    
    func fetchScannedRooms() async throws -> [ScannedRoomResponse] {
        return try await call(endpoint: API.allScannedRooms)
    }
}

extension RealScannedRoomWebRepository {
    enum API {
        case uploadScan(roomName: String, imageData: [Data])
        case scannedRoomDetails(roomID: String)
        case allScannedRooms
    }
}

extension RealScannedRoomWebRepository.API: APICall {
    var path: String {
        switch self {
        case .uploadScan:
            return "/upload"
        case let .scannedRoomDetails(roomID):
            return "/\(roomID)"
        case .allScannedRooms:
            return "/list"
        }
    }
    
    var method: String {
        switch self {
        case .uploadScan: return "POST"
        case .scannedRoomDetails, .allScannedRooms: return "GET"
        }
    }
    
    var headers: [String: String]? {
        ["Content-Type": "application/json", "Accept": "application/json"]
    }
    
    func body() throws -> Data? {
        switch self {
        case let .uploadScan(roomName, imageData):
            // This assumes a JSON payload:
            let payload: [String: Any] = [
                "roomName": roomName,
                // Encode the images appropriately (base64, or pass them as form-data).
                "images": imageData.map { $0.base64EncodedString() }
            ]
            return try JSONSerialization.data(withJSONObject: payload, options: [])
        default:
            return nil
        }
    }
}
