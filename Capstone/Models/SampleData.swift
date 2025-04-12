//
//  SampleData.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-12.
//

import SwiftUI
import SwiftData

struct SampleData: PreviewModifier {
    
    static func makeSharedContext() async throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Schema.appSchema, configurations: config)
        DBModel.Scan.makeSampleScans(in: container)
        DBModel.UploadTask.makeSampleUploadTasks(in: container)
        return container
    }
    
    func body(content: Content, context: ModelContainer) -> some View {
        content.modelContainer(context)
    }
}

extension PreviewTrait where T == Preview.ViewTraits {
    @MainActor static var sampleData: Self = .modifier(SampleData())
}

// MARK: - DBModel.Scan

extension DBModel.Scan {
    
    @MainActor static func makeSampleScans(in container: ModelContainer) {
        let context = container.mainContext
        
        let sampleDTOs: [ScanDTO] = [
            ScanDTO(
                id: UUID(),
                name: "Living Room",
                usdzURL: URL(string: "https://example.com/livingroom.usdz")!,
                processedDate: Date()
            ),
            ScanDTO(
                id: UUID(),
                name: "Kitchen",
                usdzURL: URL(string: "https://example.com/kitchen.usdz")!,
                processedDate: Date()
            ),
            ScanDTO(
                id: UUID(),
                name: "Bedroom",
                usdzURL: URL(string: "https://example.com/bedroom.usdz")!,
                processedDate: Date()
            ),
            ScanDTO(
                id: UUID(),
                name: "Bathroom",
                usdzURL: URL(string: "https://example.com/livingroom.usdz")!,
                processedDate: Date()
            ),
        ]
        
        sampleDTOs.forEach { dto in
            let scan = DBModel.Scan(dto: dto)
            context.insert(scan)
        }
    }
}

// MARK: - DBModel.UploadTask

extension DBModel.UploadTask {
    
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
            let uploadTask = DBModel.UploadTask(dto: dto)
            context.insert(uploadTask)
        }
    }
}
