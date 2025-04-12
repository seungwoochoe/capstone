//
//  UploadTask.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-11.
//

import SwiftUI
import SwiftData

struct UploadTaskDTO: Sendable {
    let id: UUID
    let name: String
    let imageURLs: [URL]
    let createdAt: Date
    let retryCount: Int
    let uploadStatus: UploadTask.Status
}

@Model
final class UploadTask {
    
    enum Status: String, Codable, Equatable {
        case pending
        case inProgress
        case failed
        case succeeded
    }
    
    var id: UUID
    var name: String
    var imageURLs: [URL]
    var createdAt: Date
    var retryCount: Int
    var uploadStatus: Status

    init(id: UUID = UUID(),
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

// MARK: - Sample Data

struct UploadTaskSampleData: PreviewModifier {
    
    static func makeSharedContext() async throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: UploadTask.self, configurations: config)
        UploadTask.makeSampleUploadTasks(in: container)
        return container
    }
    
    func body(content: Content, context: ModelContainer) -> some View {
        content.modelContainer(context)
    }
}

extension PreviewTrait where T == Preview.ViewTraits {
    @MainActor static var uploadTaskSampleData: Self = .modifier(UploadTaskSampleData())
}

extension UploadTask {
    
    @MainActor static func makeSampleUploadTasks(in container: ModelContainer) {
        let context = container.mainContext
        
        let sampleDTOs: [UploadTaskDTO] = [
            UploadTaskDTO(
                id: UUID(),
                name: "Living Room",
                imageURLs: [],
                createdAt: Date(),
                retryCount: 0,
                uploadStatus: .failed
            ),
            UploadTaskDTO(
                id: UUID(),
                name: "Kitchen Room",
                imageURLs: [],
                createdAt: Date(),
                retryCount: 0,
                uploadStatus: .inProgress
            ),
            UploadTaskDTO(
                id: UUID(),
                name: "Bedroom",
                imageURLs: [],
                createdAt: Date(),
                retryCount: 0,
                uploadStatus: .inProgress
            ),
            UploadTaskDTO(
                id: UUID(),
                name: "Bathroom",
                imageURLs: [],
                createdAt: Date(),
                retryCount: 0,
                uploadStatus: .pending
            ),
        ]
        
        sampleDTOs.forEach { dto in
            let uploadTask = UploadTask(dto: dto)
            context.insert(uploadTask)
        }
    }
}
