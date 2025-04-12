//
//  ScanDBRepository.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-11.
//

import Foundation
import SwiftData

protocol ScanDBRepository {
    func store(scanDTO: ScanDTO) async throws
    func fetchAllScans() async throws -> [ScanDTO]
    func update(scanDTO: ScanDTO, for scanID: UUID) async throws
    func delete(scanID: UUID) async throws
}

@ModelActor
final actor RealScanDBRepository: ScanDBRepository {
    
    func store(scanDTO: ScanDTO) async throws {
        let scan = DBModel.Scan(dto: scanDTO)
        try modelContext.transaction {
            modelContext.insert(scan)
        }
    }
    
    func fetchAllScans() async throws -> [ScanDTO] {
        let fetchDescriptor = FetchDescriptor<DBModel.Scan>()
        let scans = try modelContext.fetch(fetchDescriptor)
        return scans.map { $0.toDTO() }
    }
    
    func update(scanDTO: ScanDTO, for scanID: UUID) async throws {
        let predicate = #Predicate<DBModel.Scan> { $0.id == scanID }
        let fetchDescriptor = FetchDescriptor<DBModel.Scan>(predicate: predicate)
        guard let scan = try modelContext.fetch(fetchDescriptor).first else {
            // Optionally, throw an error if the scan is not found.
            return
        }
        
        try modelContext.transaction {
            scan.name = scanDTO.name
            scan.usdzURL = scanDTO.usdzURL
            scan.processedDate = scanDTO.processedDate
        }
    }
    
    func delete(scanID: UUID) async throws {
        let predicate = #Predicate<DBModel.Scan> { $0.id == scanID }
        let fetchDescriptor = FetchDescriptor<DBModel.Scan>(predicate: predicate)
        guard let scan = try modelContext.fetch(fetchDescriptor).first else {
            // Optionally, throw an error if the scan is not found.
            return
        }
        
        try modelContext.transaction {
            modelContext.delete(scan)
        }
    }
}
