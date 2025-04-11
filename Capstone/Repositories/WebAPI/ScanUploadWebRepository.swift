//
//  ScanUploadWebRepository.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-11.
//

import Foundation

// MARK: - ProcessedScanResult

struct ProcessedScanResult {
    let usdzURL: URL
    let processedDate: Date
    let status: RoomStatus
    
    enum RoomStatus {
        case completed
        case failed
    }
}

// MARK: - ScanUploadWebRepository

protocol ScanUploadWebRepository {
    func uploadScanData(roomName: String, imageURLs: [URL]) async throws -> ProcessedScanResult
}

struct RealScanUploadWebRepository: ScanUploadWebRepository {
    let session: URLSession
    let baseURL: String
    
    init(session: URLSession) {
        self.session = session
        self.baseURL = "https://your-server.com/api/scan" // update accordingly
    }
    
    func uploadScanData(roomName: String, imageURLs: [URL]) async throws -> ProcessedScanResult {
        // Build and send the request based on your API specifications.
        // For this example we simulate an API call with a delay:
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Simulated API response: create a URL for the processed USDZ file.
        let processedURL = URL(string: "\(baseURL)/3dmodels/\(roomName).usdz")!
        return ProcessedScanResult(usdzURL: processedURL, processedDate: Date(), status: .completed)
    }
}
