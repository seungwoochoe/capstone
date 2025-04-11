//
//  ScanUploadTaskDBRepository.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-11.
//

import SwiftData
import Foundation

protocol ScanUploadTaskDBRepository {
    func store(uploadTaskDTO: ScanUploadTaskDTO) async throws
    func fetchPendingUploadTasks() async throws -> [ScanUploadTaskDTO]
    func update(uploadTaskDTO: ScanUploadTaskDTO, for taskID: UUID) async throws
    func delete(taskID: UUID) async throws
}

@ModelActor
final actor RealScanUploadTaskDBRepository: ScanUploadTaskDBRepository {

    func store(uploadTaskDTO: ScanUploadTaskDTO) async throws {
        let task = ScanUploadTask(dto: uploadTaskDTO)
        try modelContext.transaction {
            modelContext.insert(task)
        }
    }
    
    func fetchPendingUploadTasks() async throws -> [ScanUploadTaskDTO] {
//        let predicate = #Predicate<ScanUploadTask> {
//            $0.uploadStatus == UploadStatus.pending ||
//            $0.uploadStatus == UploadStatus.failed
//        }
//        let fetchDescriptor = FetchDescriptor<ScanUploadTask>(predicate: predicate)
//        
//        let tasks = try modelContext.fetch(fetchDescriptor)
//        return tasks.map { $0.toDTO() }
        return []
    }
    
    func update(uploadTaskDTO: ScanUploadTaskDTO, for taskID: UUID) async throws {
        let predicate = #Predicate<ScanUploadTask> { $0.taskID == taskID }
        let fetchDescriptor = FetchDescriptor<ScanUploadTask>(predicate: predicate)
        guard let task = try modelContext.fetch(fetchDescriptor).first else {
            // Optionally, throw an error if the task is not found.
            return
        }
        
        try modelContext.transaction {
            task.roomName = uploadTaskDTO.roomName
            task.imageURLs = uploadTaskDTO.imageURLs
            task.createdAt = uploadTaskDTO.createdAt
            task.retryCount = uploadTaskDTO.retryCount
            task.uploadStatus = uploadTaskDTO.uploadStatus
        }
    }
    
    func delete(taskID: UUID) async throws {
        let predicate = #Predicate<ScanUploadTask> { $0.taskID == taskID }
        let fetchDescriptor = FetchDescriptor<ScanUploadTask>(predicate: predicate)
        guard let task = try modelContext.fetch(fetchDescriptor).first else {
            // Optionally, throw an error if the task is not found.
            return
        }
        
        try modelContext.transaction {
            modelContext.delete(task)
        }
    }
}
