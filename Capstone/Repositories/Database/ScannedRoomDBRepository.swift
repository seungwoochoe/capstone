//
//  ScannedRoomDBRepository.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-11.
//

import Foundation
import SwiftData

protocol ScannedRoomDBRepository {
    func store(scannedRoomDTO: ScannedRoomDTO) async throws
    func fetchAllScannedRooms() async throws -> [ScannedRoomDTO]
    func update(scannedRoomDTO: ScannedRoomDTO, for roomID: UUID) async throws
    func delete(roomID: UUID) async throws
}

@ModelActor
final actor RealScannedRoomDBRepository: ScannedRoomDBRepository {
    
    func store(scannedRoomDTO: ScannedRoomDTO) async throws {
        let scannedRoom = ScannedRoom(dto: scannedRoomDTO)
        try modelContext.transaction {
            modelContext.insert(scannedRoom)
        }
    }
    
    func fetchAllScannedRooms() async throws -> [ScannedRoomDTO] {
        let fetchDescriptor = FetchDescriptor<ScannedRoom>()
        let rooms = try modelContext.fetch(fetchDescriptor)
        return rooms.map { $0.toDTO() }
    }
    
    func update(scannedRoomDTO: ScannedRoomDTO, for roomID: UUID) async throws {
        let predicate = #Predicate<ScannedRoom> { $0.roomID == roomID }
        let fetchDescriptor = FetchDescriptor<ScannedRoom>(predicate: predicate)
        guard let room = try modelContext.fetch(fetchDescriptor).first else {
            // Optionally, throw an error if the room is not found.
            return
        }
        
        try modelContext.transaction {
            room.roomName = scannedRoomDTO.roomName
            room.usdzURL = scannedRoomDTO.usdzURL
            room.processedDate = scannedRoomDTO.processedDate
        }
    }
    
    func delete(roomID: UUID) async throws {
        let predicate = #Predicate<ScannedRoom> { $0.roomID == roomID }
        let fetchDescriptor = FetchDescriptor<ScannedRoom>(predicate: predicate)
        guard let room = try modelContext.fetch(fetchDescriptor).first else {
            // Optionally, throw an error if the room is not found.
            return
        }
        
        try modelContext.transaction {
            modelContext.delete(room)
        }
    }
}
