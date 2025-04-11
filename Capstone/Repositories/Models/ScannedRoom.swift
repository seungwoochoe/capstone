//
//  ScannedRoom.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import SwiftData
import Foundation

@Model
final class ScannedRoom {
    var roomName: String
    var usdzURL: URL
    var processedDate: Date

    init(roomName: String, usdzURL: URL, processedDate: Date = Date()) {
        self.roomName = roomName
        self.usdzURL = usdzURL
        self.processedDate = processedDate
    }
}
