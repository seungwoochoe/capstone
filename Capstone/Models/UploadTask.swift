//
//  UploadTask.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-11.
//

import SwiftUI
import SwiftData

struct UploadTask: Identifiable {
    let id: UUID
    var name: String
    let imageURLs: [URL]
    let createdAt: Date
    var retryCount: Int
    var uploadStatus: UploadTaskStatus
}

enum UploadTaskStatus: Codable, Equatable {
    case pending
    case inProgress
    case failed
    case succeeded
    
    var displayString: String {
        switch self {
        case .pending: return "Pending"
        case .inProgress: return "In Progress"
        case .failed: return "Failed"
        case .succeeded: return "Succeeded"
        }
    }
}

extension Persistence {
    
    @Model
    final class UploadTask {

        
        @Attribute(.unique) var id: UUID
        var name: String
        var imageURLs: [URL]
        var createdAt: Date
        var retryCount: Int
        var uploadStatus: UploadTaskStatus
        
        init(id: UUID,
             name: String,
             imageURLs: [URL],
             createdAt: Date = Date(),
             retryCount: Int = 0,
             uploadStatus: UploadTaskStatus = .pending) {
            self.id = id
            self.name = name
            self.imageURLs = imageURLs
            self.createdAt = createdAt
            self.retryCount = retryCount
            self.uploadStatus = uploadStatus
        }
    }
}

extension Persistence.UploadTask {
    
    convenience init(uploadTask: UploadTask) {
        self.init(id: uploadTask.id,
                  name: uploadTask.name,
                  imageURLs: uploadTask.imageURLs,
                  createdAt: uploadTask.createdAt,
                  retryCount: uploadTask.retryCount,
                  uploadStatus: uploadTask.uploadStatus)
    }
    
    func toDomain() -> UploadTask {
        return UploadTask(
            id: id,
            name: name,
            imageURLs: imageURLs,
            createdAt: createdAt,
            retryCount: retryCount,
            uploadStatus: uploadStatus
        )
    }
}
