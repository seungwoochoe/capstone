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

@Model
final class Scan {
    var id: UUID
    var name: String
    var usdzURL: URL
    var processedDate: Date

    init(id: UUID = UUID(),
         name: String,
         usdzURL: URL,
         processedDate: Date = Date()) {
        self.id = id
        self.name = name
        self.usdzURL = usdzURL
        self.processedDate = processedDate
    }
}

extension Scan {
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

// MARK: - Sample Data

struct ScanSampleData: PreviewModifier {
    
    static func makeSharedContext() async throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Scan.self, configurations: config)
        Scan.makeSampleScans(in: container)
        return container
    }
    
    func body(content: Content, context: ModelContainer) -> some View {
        content.modelContainer(context)
    }
}

extension PreviewTrait where T == Preview.ViewTraits {
    @MainActor static var scanSampleData: Self = .modifier(ScanSampleData())
}

extension Scan {
    
    @MainActor static func makeSampleScans(in container: ModelContainer) {
        let context = container.mainContext
        
        let sampleDTOs: [ScanDTO] = [
            ScanDTO(
                id: UUID(),
                name: "Living Room",
                usdzURL: URL(string: "https://example.com/livingroom.usdz")!,
                processedDate: Date()
            ),
            ScanDTO(
                id: UUID(),
                name: "Kitchen",
                usdzURL: URL(string: "https://example.com/kitchen.usdz")!,
                processedDate: Date()
            ),
            ScanDTO(
                id: UUID(),
                name: "Bedroom",
                usdzURL: URL(string: "https://example.com/bedroom.usdz")!,
                processedDate: Date()
            ),
            ScanDTO(
                id: UUID(),
                name: "Bathroom",
                usdzURL: URL(string: "https://example.com/livingroom.usdz")!,
                processedDate: Date()
            ),
        ]
        
        sampleDTOs.forEach { dto in
            let scan = Scan(dto: dto)
            context.insert(scan)
        }
    }
}
