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
    var remoteID: String?
    var uploadStatus: UploadTaskStatus
}

enum UploadTaskStatus: Codable, Equatable {
    case pendingUpload
    case uploading
    case waitingForResult
    case failedUpload
    case failedProcessing
    case finished
    
    var displayString: String {
        switch self {
        case .pendingUpload:
            return "Pending upload"
        case .uploading:
            return "Uploading"
        case .waitingForResult:
            return "Waiting for result"
        case .failedUpload:
            return "Failed upload"
        case .failedProcessing:
            return "Failed processing"
        case .finished:
            return "Finished"
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
        var remoteID: String?
        var uploadStatus: UploadTaskStatus
        
        init(id: UUID,
             name: String,
             imageURLs: [URL],
             createdAt: Date = Date(),
             retryCount: Int = 0,
             remoteID: String?,
             uploadStatus: UploadTaskStatus = .pendingUpload) {
            self.id = id
            self.name = name
            self.imageURLs = imageURLs
            self.createdAt = createdAt
            self.retryCount = retryCount
            self.remoteID = remoteID
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
                  remoteID: nil,
                  uploadStatus: uploadTask.uploadStatus)
    }
    
    func toDomain() -> UploadTask {
        return UploadTask(
            id: id,
            name: name,
            imageURLs: imageURLs,
            createdAt: createdAt,
            retryCount: retryCount,
            remoteID: remoteID,
            uploadStatus: uploadStatus
        )
    }
}
