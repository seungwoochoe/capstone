//
//  UploadTask.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-11.
//

import SwiftUI
import SwiftData

struct UploadTask: Identifiable, Equatable {
    let id: UUID
    var name: String
    let fileURL: URL
    let createdAt: Date
    var retryCount: Int
    var uploadStatus: UploadTaskStatus
}

enum UploadTaskStatus: Codable, Equatable {
    case pendingUpload
    case uploading
    case waitingForResult
    case failedUpload
    case failedProcessing
    
    var displayString: String {
        switch self {
        case .pendingUpload:
            return "Pending upload"
        case .uploading:
            return "Uploading…"
        case .waitingForResult:
            return "Waiting for result…"
        case .failedUpload:
            return "Failed upload"
        case .failedProcessing:
            return "Failed processing"
        }
    }
}

extension Persistence {
    
    @Model
    final class UploadTask {

        @Attribute(.unique) var id: UUID
        var name: String
        var fileURL: URL
        var createdAt: Date
        var retryCount: Int
        var uploadStatus: UploadTaskStatus
        
        init(id: UUID,
             name: String,
             fileURL: URL,
             createdAt: Date = Date(),
             retryCount: Int = 0,
             uploadStatus: UploadTaskStatus = .pendingUpload) {
            self.id = id
            self.name = name
            self.fileURL = fileURL
            self.createdAt = createdAt
            self.retryCount = retryCount
            self.uploadStatus = uploadStatus
        }
    }
}

extension Persistence.UploadTask {
    
    convenience init(uploadTask: UploadTask) {
        self.init(
            id: uploadTask.id,
            name: uploadTask.name,
            fileURL: uploadTask.fileURL,
            createdAt: uploadTask.createdAt,
            retryCount: uploadTask.retryCount,
            uploadStatus: uploadTask.uploadStatus
        )
    }
    
    func toDomain() -> UploadTask {
        return UploadTask(
            id: id,
            name: name,
            fileURL: fileURL,
            createdAt: createdAt,
            retryCount: retryCount,
            uploadStatus: uploadStatus
        )
    }
}
