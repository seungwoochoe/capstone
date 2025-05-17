//
//  UploadTaskDBRepositoryTests.swift
//  CapstoneTests
//
//  Created by Seungwoo Choe on 2025-05-06.
//

import Foundation
import SwiftData
import Testing
@testable import Capstone

@Suite("RealUploadTaskDBRepository Tests")
struct RealUploadTaskDBRepositoryTests {
    
    let repository = RealUploadTaskDBRepository(modelContainer: .inMemory)
    
    @Test("fetch returns empty when repository is new")
    func fetchEmpty() async throws {
        let tasks = try await repository.fetch()
        #expect(tasks.isEmpty)
    }
    
    @Test("store and fetch returns stored task")
    func storeAndFetch() async throws {
        let sample = UploadTask.sample
        try await repository.store(sample)
        
        let tasks = try await repository.fetch()
        let fetched = try #require(tasks.first)
        #expect(fetched.id == sample.id)
        #expect(fetched.name == sample.name)
        #expect(fetched.imageURLs == sample.imageURLs)
        #expect(fetched.retryCount == sample.retryCount)
        #expect(fetched.uploadStatus == sample.uploadStatus)
    }
    
    @Test("update modifies existing task")
    func updateTask() async throws {
        var sample = UploadTask.sample
        try await repository.store(sample)
        
        sample.name = "Updated Name"
        sample.retryCount = 5
        sample.uploadStatus = .uploading
        try await repository.update(sample)
        
        let tasks = try await repository.fetch()
        let updated = try #require(tasks.first)
        #expect(updated.name == "Updated Name")
        #expect(updated.retryCount == 5)
        #expect(updated.uploadStatus == .uploading)
    }
    
    @Test("delete removes the task")
    func deleteTask() async throws {
        let sample = UploadTask.sample
        try await repository.store(sample)
        
        try await repository.delete(sample)
        let tasks = try await repository.fetch()
        #expect(tasks.isEmpty)
    }
    
    @Test("update on non-existing task throws notFound error")
    func updateNonExistingThrows() async throws {
        let nonExistent = UploadTask(
            id: UUID(),
            name: "Nonexistent",
            imageURLs: [],
            createdAt: Date(),
            retryCount: 0,
            uploadStatus: .failedUpload
        )
        await #expect {
            try await repository.update(nonExistent)
        } throws: { error in
            guard let modelError = error as? ModelContextError,
                  case .notFound(let id) = modelError
            else { return false }
            return id == nonExistent.id
        }
    }
    
    @Test("delete on non-existing task throws notFound error")
    func deleteNonExistingThrows() async throws {
        let nonExistent = UploadTask(
            id: UUID(),
            name: "Nonexistent",
            imageURLs: [],
            createdAt: Date(),
            retryCount: 0,
            uploadStatus: .failedUpload
        )
        await #expect {
            try await repository.delete(nonExistent)
        } throws: { error in
            guard let modelError = error as? ModelContextError,
                  case .notFound(let id) = modelError
            else { return false }
            return id == nonExistent.id
        }
    }
}
