//
//  RoomScanRepository.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import Foundation

protocol RoomScanRepository {
    func uploadScanData(room: ScannedRoom) async throws
    func fetchScannedRooms() async throws -> [ScannedRoom]
}
