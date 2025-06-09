//
//  UploadTaskLocalRepository.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-11.
//

import SwiftData
import OSLog

protocol UploadTaskLocalRepository {
    func fetch() async throws -> [UploadTask]
    func store(_ uploadTask: UploadTask) async throws
    func update(_ uploadTask: UploadTask) async throws
    func delete(_ uploadTask: UploadTask) async throws
}

@ModelActor
final actor RealUploadTaskLocalRepository: UploadTaskLocalRepository {
    
    private let logger = Logger.forType(RealUploadTaskLocalRepository.self)
    
    func fetch() async throws -> [UploadTask] {
        do {
            let descriptor = FetchDescriptor<Persistence.UploadTask>()
            let models = try modelContext.fetch(descriptor)
            let tasks = models.map { $0.toDomain() }
            logger.debug("Fetched \(tasks.count) upload task(s).")
            return tasks
        } catch {
            logger.error("Fetch failed: \(error.localizedDescription, privacy: .public).")
            throw error
        }
    }
    
    func store(_ uploadTask: UploadTask) async throws {
        do {
            let task = Persistence.UploadTask(uploadTask: uploadTask)
            try modelContext.transaction {
                modelContext.insert(task)
            }
            logger.debug("Stored upload task with id: \(uploadTask.id.uuidString, privacy: .public), name: \(uploadTask.name, privacy: .public).")
        } catch {
            logger.error("Store failed for id: \(uploadTask.id.uuidString, privacy: .public). Error: \(error.localizedDescription, privacy: .public).")
            throw error
        }
    }
    
    func update(_ uploadTask: UploadTask) async throws {
        do {
            guard let existing: Persistence.UploadTask = try modelContext.existingModel(for: uploadTask.id) else {
                logger.warning("Update skipped. Upload task not found for id: \(uploadTask.id.uuidString, privacy: .public).")
                return
            }
            try modelContext.transaction {
                existing.name = uploadTask.name
                existing.retryCount = uploadTask.retryCount
                existing.uploadStatus = uploadTask.uploadStatus
            }
            logger.debug("Updated upload task with id: \(uploadTask.id.uuidString, privacy: .public), name: \(uploadTask.name, privacy: .public).")
        } catch {
            logger.error("Update failed for id: \(uploadTask.id.uuidString, privacy: .public). Error: \(error.localizedDescription, privacy: .public).")
            throw error
        }
    }
    
    func delete(_ uploadTask: UploadTask) async throws {
        do {
            guard let existing: Persistence.UploadTask = try modelContext.existingModel(for: uploadTask.id) else {
                logger.warning("Delete skipped. Upload task not found for id: \(uploadTask.id.uuidString, privacy: .public).")
                return
            }
            try modelContext.transaction {
                modelContext.delete(existing)
            }
            logger.debug("Deleted upload task with id: \(uploadTask.id.uuidString, privacy: .public).")
        } catch {
            logger.error("Delete failed for id: \(uploadTask.id.uuidString, privacy: .public). Error: \(error.localizedDescription, privacy: .public).")
            throw error
        }
    }
}
