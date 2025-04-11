//
//  ScanUploadTask.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-11.
//

import SwiftData
import Foundation

@Model
final class ScanUploadTask {
    var roomName: String
    var imageURLs: [URL]
    var createdAt: Date
    var retryCount: Int
    var uploadStatus: UploadStatus

    init(roomName: String,
         imageURLs: [URL],
         createdAt: Date = Date(),
         retryCount: Int = 0,
         uploadStatus: UploadStatus = .pending) {
        self.roomName = roomName
        self.imageURLs = imageURLs
        self.createdAt = createdAt
        self.retryCount = retryCount
        self.uploadStatus = uploadStatus
    }
}

enum UploadStatus: String, Codable, Equatable {
    case pending
    case inProgress
    case failed
    case succeeded
}
