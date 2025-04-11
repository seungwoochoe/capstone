//
//  ScanRoomInteractor.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import Foundation

struct ScanRoomInteractor {
    let webRepository: RoomScanWebRepository
    let persistenceRepository: RoomScanPersistenceRepository
    
    /// Initiates the room scan upload process.
    func startScan(with room: ScannedRoom) async throws {
        // (For example, check permissions, run ARKit/RealityKit scan, sample images, etc.)
        try await webRepository.uploadImages(roomName: room.roomName, images: room.imageURLs)
        room.status = .processing
        try await persistenceRepository.save(room: room)
    }
}
