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
    var name: String
    let createdAt: Date
    
    func modelURL(fileManager: FileManager) -> URL {
        fileManager
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(self.id.uuidString)
            .appendingPathComponent("model.ply")
    }
}

extension Persistence {
    
    @Model
    final class Scan {
        @Attribute(.unique) var id: UUID
        var name: String
        var createdAt: Date
        
        init(id: UUID,
             name: String,
             createdAt: Date = Date()) {
            self.id = id
            self.name = name
            self.createdAt = createdAt
        }
    }
}

extension Persistence.Scan {
    
    convenience init(scan: Scan) {
        self.init(
            id: scan.id,
            name: scan.name,
            createdAt: scan.createdAt
        )
    }

    func toDomain() -> Scan {
        return Scan(
            id: id,
            name: name,
            createdAt: createdAt
        )
    }
}
