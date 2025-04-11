//
//  RoomScanWebRepository.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import Foundation

struct RoomScanWebRepository {
    let session: URLSession
    
    /// Uploads the sample images (assumed to be stored in temporary files) to the server.
    func uploadImages(roomName: String, images: [URL]) async throws {
        // Implement the HTTP call to upload the scan images.
        // For now, simulate network latency.
        try await Task.sleep(nanoseconds: 1_000_000_000)
    }
}
