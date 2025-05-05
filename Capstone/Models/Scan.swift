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
    let usdzURL: URL
    let processedDate: Date
}

extension Persistence {
    
    @Model
    final class Scan {
        @Attribute(.unique) var id: UUID
        var name: String
        var usdzURL: URL
        var processedDate: Date
        
        init(id: UUID,
             name: String,
             usdzURL: URL,
             processedDate: Date = Date()) {
            self.id = id
            self.name = name
            self.usdzURL = usdzURL
            self.processedDate = processedDate
        }
    }
}

extension Persistence.Scan {
    
    convenience init(scan: Scan) {
        self.init(id: scan.id,
                  name: scan.name,
                  usdzURL: scan.usdzURL,
                  processedDate: scan.processedDate)
    }

    func toDomain() -> Scan {
        return Scan(
            id: id,
            name: name,
            usdzURL: usdzURL,
            processedDate: processedDate
        )
    }
}
