//
//  ScanLocalRepository.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-11.
//

import SwiftData
import OSLog

protocol ScanLocalRepository {
    func fetch() async throws -> [Scan]
    func store(_ scan: Scan) async throws
    func update(_ scan: Scan) async throws
    func delete(_ scan: Scan) async throws
}

@ModelActor
final actor RealScanLocalRepository: ScanLocalRepository {
    
    private let logger = Logger.forType(RealScanLocalRepository.self)
    
    func fetch() async throws -> [Scan] {
        do {
            let descriptor = FetchDescriptor<Persistence.Scan>()
            let models = try modelContext.fetch(descriptor)
            let scans = models.map { $0.toDomain() }
            logger.debug("Fetched \(scans.count) scan(s).")
            return scans
        } catch {
            logger.error("Fetch failed: \(error.localizedDescription, privacy: .public).")
            throw error
        }
    }
    
    func store(_ scan: Scan) async throws {
        do {
            let persistenceModel = Persistence.Scan(scan: scan)
            try modelContext.transaction {
                modelContext.insert(persistenceModel)
            }
            logger.debug("Stored scan with id: \(scan.id.uuidString, privacy: .public), name: \(scan.name, privacy: .public).")
        } catch {
            logger.error("Store failed for id: \(scan.id.uuidString, privacy: .public). Error: \(error.localizedDescription, privacy: .public).")
            throw error
        }
    }
    
    func update(_ scan: Scan) async throws {
        do {
            guard let existing: Persistence.Scan = try modelContext.existingModel(for: scan.id) else {
                logger.warning("Update skipped. Scan not found for id: \(scan.id.uuidString, privacy: .public).")
                return
            }
            try modelContext.transaction {
                existing.name = scan.name
                existing.createdAt = scan.createdAt
            }
            logger.debug("Updated scan with id: \(scan.id.uuidString, privacy: .public), name: \(scan.name, privacy: .public).")
        } catch {
            logger.error("Update failed for id: \(scan.id.uuidString, privacy: .public). Error: \(error.localizedDescription, privacy: .public).")
            throw error
        }
    }
    
    func delete(_ scan: Scan) async throws {
        do {
            guard let existing: Persistence.Scan = try modelContext.existingModel(for: scan.id) else {
                logger.warning("Delete skipped. Scan not found for id: \(scan.id.uuidString, privacy: .public).")
                return
            }
            try modelContext.transaction {
                modelContext.delete(existing)
            }
            logger.debug("Deleted scan with id: \(scan.id.uuidString, privacy: .public).")
        } catch {
            logger.error("Delete failed for id: \(scan.id.uuidString, privacy: .public). Error: \(error.localizedDescription, privacy: .public).")
            throw error
        }
    }
}
