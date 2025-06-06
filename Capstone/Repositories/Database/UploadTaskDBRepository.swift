//
//  UploadTaskDBRepository.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-11.
//

import SwiftData

protocol UploadTaskDBRepository {
    func fetch() async throws -> [UploadTask]
    func store(_ uploadTask: UploadTask) async throws
    func update(_ uploadTask: UploadTask) async throws
    func delete(_ uploadTask: UploadTask) async throws
}

@ModelActor
final actor RealUploadTaskDBRepository: UploadTaskDBRepository {
    
    func fetch() async throws -> [UploadTask] {
        let fetchDescriptor = FetchDescriptor<Persistence.UploadTask>()
        let tasks = try modelContext.fetch(fetchDescriptor)
        return tasks.map { $0.toDomain() }
    }
    
    func store(_ uploadTask: UploadTask) async throws {
        let task = Persistence.UploadTask(uploadTask: uploadTask)
        try modelContext.transaction {
            modelContext.insert(task)
        }
    }
    
    func update(_ uploadTask: UploadTask) async throws {
        guard let existing: Persistence.UploadTask = try modelContext.existingModel(for: uploadTask.id) else { return }
        
        try modelContext.transaction {
            existing.name = uploadTask.name
            existing.retryCount = uploadTask.retryCount
            existing.uploadStatus = uploadTask.uploadStatus
        }
    }
    
    func delete(_ uploadTask: UploadTask) async throws {
        guard let existing: Persistence.UploadTask = try modelContext.existingModel(for: uploadTask.id) else { return }
        
        try modelContext.transaction {
            modelContext.delete(existing)
        }
    }
}
