//
//  ScannedRoomsInteractor.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import Foundation

struct ScannedRoomsInteractor {
    let persistenceRepository: RoomScanPersistenceRepository
    
    func getScannedRooms() async throws -> [ScannedRoom] {
        return try await persistenceRepository.fetchScannedRooms()
    }
    
    func delete(room: ScannedRoom) async throws {
        // Implement local deletion using SwiftData.
    }
}
