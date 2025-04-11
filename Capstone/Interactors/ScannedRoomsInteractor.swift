//
//  ScannedRoomsInteractor.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import Foundation

protocol ScannedRoomsInteractor {
    func getScannedRooms() async throws -> [ScannedRoom]
    func delete(room: ScannedRoom) async throws
}

struct RealScannedRoomsInteractor: ScannedRoomsInteractor {
    let webRepository: ScannedRoomWebRepository
    let persistenceRepository: ScannedRoomDBRepository
    
    func getScannedRooms() async throws -> [ScannedRoom] {
        let scannedRoomDTOs = try await persistenceRepository.fetchAllScannedRooms()
        return scannedRoomDTOs.map { ScannedRoom(dto: $0) }
    }
    
    func delete(room: ScannedRoom) async throws {
        try await persistenceRepository.delete(roomID: room.roomID)
    }
}

struct StubScannedRoomsInteractor: ScannedRoomsInteractor {
    
    func getScannedRooms() async throws -> [ScannedRoom] {
        return []
    }
    
    func delete(room: ScannedRoom) async throws {
        
    }    
}
