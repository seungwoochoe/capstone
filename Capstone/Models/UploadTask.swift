//
//  UploadTask.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-11.
//

import SwiftUI
import SwiftData

extension DBModel {
    
    @Model
    final class UploadTask {
        
        enum Status: String, Codable, Equatable {
            case pending
            case inProgress
            case failed
            case succeeded
        }
        
        @Attribute(.unique) var id: UUID
        var name: String
        var imageURLs: [URL]
        var createdAt: Date
        var retryCount: Int
        var uploadStatus: Status
        
        init(id: UUID,
             name: String,
             imageURLs: [URL],
             createdAt: Date = Date(),
             retryCount: Int = 0,
             uploadStatus: Status = .pending) {
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
}

struct UploadTaskDTO: Sendable {
    let id: UUID
    let name: String
    let imageURLs: [URL]
    let createdAt: Date
    let retryCount: Int
    let uploadStatus: DBModel.UploadTask.Status
}

extension UploadTaskDTO {
    static let sample = UploadTaskDTO(
        id: UUID(),
        name: "Sample",
        imageURLs: [URL(string: "https://example.com/image1.jpg")!],
        createdAt: Date(),
        retryCount: 0,
        uploadStatus: .pending
    )
}
