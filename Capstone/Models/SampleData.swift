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
        let container = ModelContainer.inMemory
        Persistence.Scan.makeSampleScans(in: container)
        Persistence.UploadTask.makeSampleUploadTasks(in: container)
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

extension Persistence.Scan {
    
    @MainActor static func makeSampleScans(in container: ModelContainer) {
        let context = container.mainContext
        
        let sampleDTOs: [Scan] = [
            Scan(
                id: UUID(),
                name: "Living Room",
                usdzURL: URL(string: "https://example.com/livingroom.usdz")!,
                processedDate: Date()
            ),
            Scan(
                id: UUID(),
                name: "Kitchen",
                usdzURL: URL(string: "https://example.com/kitchen.usdz")!,
                processedDate: Date()
            ),
            Scan(
                id: UUID(),
                name: "Bedroom",
                usdzURL: URL(string: "https://example.com/bedroom.usdz")!,
                processedDate: Date()
            ),
            Scan(
                id: UUID(),
                name: "Bathroom",
                usdzURL: URL(string: "https://example.com/livingroom.usdz")!,
                processedDate: Date()
            ),
        ]
        
        sampleDTOs.forEach { dto in
            let scan = Persistence.Scan(scan: dto)
            context.insert(scan)
        }
    }
}

// MARK: - DBModel.UploadTask

extension Persistence.UploadTask {
    
    @MainActor static func makeSampleUploadTasks(in container: ModelContainer) {
        let context = container.mainContext
        
        let sampleDTOs: [UploadTask] = [
            UploadTask(
                id: UUID(),
                name: "Living Room",
                imageURLs: [],
                createdAt: Date(),
                retryCount: 0,
                uploadStatus: .failed
            ),
            UploadTask(
                id: UUID(),
                name: "Kitchen Room",
                imageURLs: [],
                createdAt: Date(),
                retryCount: 0,
                uploadStatus: .inProgress
            ),
            UploadTask(
                id: UUID(),
                name: "Bedroom",
                imageURLs: [],
                createdAt: Date(),
                retryCount: 0,
                uploadStatus: .inProgress
            ),
            UploadTask(
                id: UUID(),
                name: "Bathroom",
                imageURLs: [],
                createdAt: Date(),
                retryCount: 0,
                uploadStatus: .pending
            ),
        ]
        
        sampleDTOs.forEach { dto in
            let uploadTask = Persistence.UploadTask(uploadTask: dto)
            context.insert(uploadTask)
        }
    }
}
