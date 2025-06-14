//
//  ScanLocalRepositoryTests.swift
//  CapstoneTests
//
//  Created by Seungwoo Choe on 2025-05-06.
//

import Foundation
import Testing
@testable import Capstone

@Suite("RealScanLocalRepositoryTests")
struct RealScanLocalRepositoryTests {
    
    let repository = RealScanLocalRepository(modelContainer: .inMemory)
    
    @Test("fetch returns empty when repository is new")
    func fetchEmpty() async throws {
        let scans = try await repository.fetch()
        #expect(scans.isEmpty)
    }
    
    @Test("store and fetch returns stored scan")
    func storeAndFetch() async throws {
        let sample = Scan(
            id: UUID(),
            name: "Sample Scan",
            createdAt: Date()
        )
        try await repository.store(sample)
        
        let scans = try await repository.fetch()
        let fetched = try #require(scans.first)
        #expect(fetched.id == sample.id)
        #expect(fetched.name == sample.name)
        #expect(fetched.createdAt == sample.createdAt)
    }
    
    @Test("update modifies existing scan")
    func updateScan() async throws {
        // Store initial scan
        var sample = Scan(
            id: UUID(),
            name: "Original Scan",
            createdAt: Date()
        )
        try await repository.store(sample)
        
        // Prepare updated values
        let newDate = Date().addingTimeInterval(3600)
        sample = Scan(
            id: sample.id,
            name: "Updated Scan",
            createdAt: newDate
        )
        try await repository.update(sample)
        
        let scans = try await repository.fetch()
        let updated = try #require(scans.first)
        #expect(updated.name == "Updated Scan")
        #expect(updated.createdAt == sample.createdAt)
    }
    
    @Test("delete removes the scan")
    func deleteScan() async throws {
        let sample = Scan(
            id: UUID(),
            name: "To Delete",
            createdAt: Date()
        )
        try await repository.store(sample)
        try await repository.delete(sample)
        
        let scans = try await repository.fetch()
        #expect(scans.isEmpty)
    }
    
    @Test("update on non-existing scan throws notFound error")
    func updateNonExistingThrows() async throws {
        let nonExistent = Scan(
            id: UUID(),
            name: "Nonexistent",
            createdAt: Date()
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
    
    @Test("delete on non-existing scan throws notFound error")
    func deleteNonExistingThrows() async throws {
        let nonExistent = Scan(
            id: UUID(),
            name: "Nonexistent",
            createdAt: Date()
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
