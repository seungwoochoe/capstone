//
//  UploadTaskDBRepository.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-11.
//

import SwiftData
import Foundation

protocol UploadTaskDBRepository {
    func store(uploadTaskDTO: UploadTaskDTO) async throws
    func fetchPendingUploadTasks() async throws -> [UploadTaskDTO]
    func update(uploadTaskDTO: UploadTaskDTO, for taskID: UUID) async throws
    func delete(taskID: UUID) async throws
}

@ModelActor
final actor RealUploadTaskDBRepository: UploadTaskDBRepository {

    func store(uploadTaskDTO: UploadTaskDTO) async throws {
        let task = UploadTask(dto: uploadTaskDTO)
        try modelContext.transaction {
            modelContext.insert(task)
        }
    }
    
    func fetchPendingUploadTasks() async throws -> [UploadTaskDTO] {
        // Workaround for the issue where #Predicate doesn’t work with enums
        let pending = UploadTask.Status.pending
        let failed = UploadTask.Status.failed
        
        let predicate = #Predicate<UploadTask> {
            $0.uploadStatus == pending ||
            $0.uploadStatus == failed
        }
        let fetchDescriptor = FetchDescriptor<UploadTask>(predicate: predicate)
        
        let tasks = try modelContext.fetch(fetchDescriptor)
        return tasks.map { $0.toDTO() }
    }
    
    func update(uploadTaskDTO: UploadTaskDTO, for taskID: UUID) async throws {
        let predicate = #Predicate<UploadTask> { $0.id == taskID }
        let fetchDescriptor = FetchDescriptor<UploadTask>(predicate: predicate)
        guard let task = try modelContext.fetch(fetchDescriptor).first else {
            // Optionally, throw an error if the task is not found.
            return
        }
        
        try modelContext.transaction {
            task.name = uploadTaskDTO.name
            task.imageURLs = uploadTaskDTO.imageURLs
            task.createdAt = uploadTaskDTO.createdAt
            task.retryCount = uploadTaskDTO.retryCount
            task.uploadStatus = uploadTaskDTO.uploadStatus
        }
    }
    
    func delete(taskID: UUID) async throws {
        let predicate = #Predicate<UploadTask> { $0.id == taskID }
        let fetchDescriptor = FetchDescriptor<UploadTask>(predicate: predicate)
        guard let task = try modelContext.fetch(fetchDescriptor).first else {
            // Optionally, throw an error if the task is not found.
            return
        }
        
        try modelContext.transaction {
            modelContext.delete(task)
        }
    }
}
