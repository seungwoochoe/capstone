//
//  Scan.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import SwiftUI
import SwiftData

struct ScanDTO: Sendable {
    let id: UUID
    let name: String
    let usdzURL: URL
    let processedDate: Date
}

extension DBModel {
    
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
        
        convenience init(dto: ScanDTO) {
            self.init(id: dto.id,
                      name: dto.name,
                      usdzURL: dto.usdzURL,
                      processedDate: dto.processedDate)
        }
        
        func toDTO() -> ScanDTO {
            return ScanDTO(
                id: id,
                name: name,
                usdzURL: usdzURL,
                processedDate: processedDate
            )
        }
    }
}
