//
//  ScanDBRepository.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-11.
//

import SwiftData

protocol ScanDBRepository {
    func fetch() async throws -> [Scan]
    func store(_ scan: Scan) async throws
    func update(_ scan: Scan) async throws
    func delete(_ scan: Scan) async throws
}

@ModelActor
final actor RealScanDBRepository: ScanDBRepository {
    
    func fetch() async throws -> [Scan] {
        let fetchDescriptor = FetchDescriptor<Persistence.Scan>()
        let scans = try modelContext.fetch(fetchDescriptor)
        return scans.map { $0.toDomain() }
    }
    
    func store(_ scan: Scan) async throws {
        let scan = Persistence.Scan(scan: scan)
        try modelContext.transaction {
            modelContext.insert(scan)
        }
    }
    
    func update(_ scan: Scan) async throws {
        guard let existing: Persistence.Scan = try modelContext.existingModel(for: scan.id) else { return }
        
        try modelContext.transaction {
            existing.name = scan.name
            existing.usdzURL = scan.usdzURL
            existing.processedDate = scan.processedDate
        }
    }
    
    func delete(_ scan: Scan) async throws {
        guard let existing: Persistence.Scan = try modelContext.existingModel(for: scan.id) else { return }
        
        try modelContext.transaction {
            modelContext.delete(existing)
        }
    }
}
