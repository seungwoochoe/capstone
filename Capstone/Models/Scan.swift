//
//  Scan.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import Foundation
import SwiftData

struct Scan: Identifiable, Hashable {
    let id: UUID
    let name: String
    let processedDate: Date
    
    func usdzURL(fileManager: FileManager) -> URL {
        fileManager
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(self.id.uuidString)
            .appendingPathComponent("model.usdz")
    }
}

extension Persistence {
    
    @Model
    final class Scan {
        @Attribute(.unique) var id: UUID
        var name: String
        var processedDate: Date
        
        init(id: UUID,
             name: String,
             processedDate: Date = Date()) {
            self.id = id
            self.name = name
            self.processedDate = processedDate
        }
    }
}

extension Persistence.Scan {
    
    convenience init(scan: Scan) {
        self.init(
            id: scan.id,
            name: scan.name,
            processedDate: scan.processedDate
        )
    }

    func toDomain() -> Scan {
        return Scan(
            id: id,
            name: name,
            processedDate: processedDate
        )
    }
}
