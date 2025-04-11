//
//  ScannedRoom.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import SwiftData
import Foundation

struct ScannedRoomDTO: Sendable {
    let roomID: UUID
    let roomName: String
    let usdzURL: URL
    let processedDate: Date
}

@Model
final class ScannedRoom {
    var roomID: UUID
    var roomName: String
    var usdzURL: URL
    var processedDate: Date

    init(roomID: UUID = UUID(),
         roomName: String,
         usdzURL: URL,
         processedDate: Date = Date()) {
        self.roomID = roomID
        self.roomName = roomName
        self.usdzURL = usdzURL
        self.processedDate = processedDate
    }
}

extension ScannedRoom {
    convenience init(dto: ScannedRoomDTO) {
        self.init(roomID: dto.roomID,
                  roomName: dto.roomName,
                  usdzURL: dto.usdzURL,
                  processedDate: dto.processedDate)
    }
    
    func toDTO() -> ScannedRoomDTO {
        return ScannedRoomDTO(
            roomID: roomID,
            roomName: roomName,
            usdzURL: usdzURL,
            processedDate: processedDate
        )
    }
}
