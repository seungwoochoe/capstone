//
//  UploadTask.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-11.
//

import SwiftData
import Foundation

struct UploadTaskDTO: Sendable {
    let id: UUID
    let name: String
    let imageURLs: [URL]
    let createdAt: Date
    let retryCount: Int
    let uploadStatus: UploadStatus
}

@Model
final class UploadTask {
    var id: UUID
    var name: String
    var imageURLs: [URL]
    var createdAt: Date
    var retryCount: Int
    var uploadStatus: UploadStatus

    init(id: UUID = UUID(),
         name: String,
         imageURLs: [URL],
         createdAt: Date = Date(),
         retryCount: Int = 0,
         uploadStatus: UploadStatus = .pending) {
        self.id = id
        self.name = name
        self.imageURLs = imageURLs
        self.createdAt = createdAt
        self.retryCount = retryCount
        self.uploadStatus = uploadStatus
    }
    
    convenience init(dto: UploadTaskDTO) {
        self.init(id: dto.id,
                  name: dto.name,
                  imageURLs: dto.imageURLs,
                  createdAt: dto.createdAt,
                  retryCount: dto.retryCount,
                  uploadStatus: dto.uploadStatus)
    }
    
    func toDTO() -> UploadTaskDTO {
        return UploadTaskDTO(
            id: id,
            name: name,
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
