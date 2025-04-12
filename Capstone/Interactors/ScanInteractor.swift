//
//  ScanInteractor.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import Foundation

protocol ScanInteractor {
    func getScans() async throws -> [Scan]
    func delete(scan: Scan) async throws
}

struct RealScanInteractor: ScanInteractor {
    let webRepository: ScanWebRepository
    let persistenceRepository: ScanDBRepository
    
    func getScans() async throws -> [Scan] {
        let scanDTOs = try await persistenceRepository.fetchAllScans()
        return scanDTOs.map { Scan(dto: $0) }
    }
    
    func delete(scan: Scan) async throws {
        try await persistenceRepository.delete(scanID: scan.id)
    }
}

struct StubScanInteractor: ScanInteractor {
    
    func getScans() async throws -> [Scan] {
        return []
    }
    
    func delete(scan: Scan) async throws {
        
    }    
}
