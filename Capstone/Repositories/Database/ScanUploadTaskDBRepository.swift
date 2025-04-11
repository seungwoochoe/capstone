//
//  ScanUploadTaskDBRepository.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-11.
//

import SwiftData
import Foundation

protocol ScanUploadTaskDBRepository {
    func store(uploadTask: ScanUploadTask) async throws
    func fetchPendingUploadTasks() async throws -> [ScanUploadTask]
    func update(uploadTask: ScanUploadTask) async throws
    func delete(uploadTask: ScanUploadTask) async throws
}

@ModelActor
final actor RealScanUploadTaskDBRepository: ScanUploadTaskDBRepository {
    func store(uploadTask: ScanUploadTask) async throws {
        try modelContext.transaction {
            modelContext.insert(uploadTask)
        }
    }
    
    func fetchPendingUploadTasks() async throws -> [ScanUploadTask] {
        let fetchDescriptor = FetchDescriptor<ScanUploadTask>(predicate: #Predicate<ScanUploadTask> {
            $0.uploadStatus == .pending || $0.uploadStatus == .failed
        })
        return try modelContainer.mainContext.fetch(fetchDescriptor)
    }
    
    func update(uploadTask: ScanUploadTask) async throws {
        try modelContext.transaction {
            // With SwiftData, changes to the model are tracked automatically.
            // Use a transaction if you need to force a commit.
        }
    }
    
    func delete(uploadTask: ScanUploadTask) async throws {
        try modelContext.transaction {
            modelContext.delete(uploadTask)
        }
    }
}
