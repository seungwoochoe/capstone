//
//  ScanUploadTask.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-11.
//

import SwiftData
import Foundation

struct ScanUploadTaskDTO: Sendable {
    let taskID: UUID
    let roomName: String
    let imageURLs: [URL]
    let createdAt: Date
    let retryCount: Int
    let uploadStatus: UploadStatus
}

@Model
final class ScanUploadTask {
    var taskID: UUID
    var roomName: String
    var imageURLs: [URL]
    var createdAt: Date
    var retryCount: Int
    var uploadStatus: UploadStatus

    init(taskID: UUID = UUID(),
         roomName: String,
         imageURLs: [URL],
         createdAt: Date = Date(),
         retryCount: Int = 0,
         uploadStatus: UploadStatus = .pending) {
        self.taskID = taskID
        self.roomName = roomName
        self.imageURLs = imageURLs
        self.createdAt = createdAt
        self.retryCount = retryCount
        self.uploadStatus = uploadStatus
    }
    
    convenience init(dto: ScanUploadTaskDTO) {
        self.init(taskID: dto.taskID,
                  roomName: dto.roomName,
                  imageURLs: dto.imageURLs,
                  createdAt: dto.createdAt,
                  retryCount: dto.retryCount,
                  uploadStatus: dto.uploadStatus)
    }
    
    func toDTO() -> ScanUploadTaskDTO {
        return ScanUploadTaskDTO(
            taskID: taskID,
            roomName: roomName,
            imageURLs: imageURLs,
            createdAt: createdAt,
            retryCount: retryCount,
            uploadStatus: uploadStatus
        )
    }
}

enum UploadStatus: String, Codable, Equatable {
    case pending
    case inProgress
    case failed
    case succeeded
}
