//
//  SampleData.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-12.
//

import SwiftUI
import SwiftData

struct SampleData: PreviewModifier {
    
    static func makeSharedContext() async throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: ScannedRoom.self, configurations: config)
        ScannedRoom.makeSampleRooms(in: container)
        return container
    }
    
    func body(content: Content, context: ModelContainer) -> some View {
        content.modelContainer(context)
    }
}

extension PreviewTrait where T == Preview.ViewTraits {
    @MainActor static var sampleData: Self = .modifier(SampleData())
}

// MARK: - ScannedRoom

extension ScannedRoom {
    
    @MainActor static func makeSampleRooms(in container: ModelContainer) {
        let context = container.mainContext
        
        let sampleDTOs: [ScannedRoomDTO] = [
            ScannedRoomDTO(
                roomID: UUID(),
                roomName: "Living Room",
                usdzURL: URL(string: "https://example.com/livingroom.usdz")!,
                processedDate: Date()
            ),
            ScannedRoomDTO(
                roomID: UUID(),
                roomName: "Kitchen",
                usdzURL: URL(string: "https://example.com/kitchen.usdz")!,
                processedDate: Date()
            ),
            ScannedRoomDTO(
                roomID: UUID(),
                roomName: "Bedroom",
                usdzURL: URL(string: "https://example.com/bedroom.usdz")!,
                processedDate: Date()
            ),
            ScannedRoomDTO(
                roomID: UUID(),
                roomName: "Bathroom",
                usdzURL: URL(string: "https://example.com/livingroom.usdz")!,
                processedDate: Date()
            ),
            ScannedRoomDTO(
                            roomID: UUID(),
                            roomName: "Living Room",
                            usdzURL: URL(string: "https://example.com/livingroom.usdz")!,
                            processedDate: Date()
                        ),
                        ScannedRoomDTO(
                            roomID: UUID(),
                            roomName: "Kitchen",
                            usdzURL: URL(string: "https://example.com/kitchen.usdz")!,
                            processedDate: Date()
                        ),
                        ScannedRoomDTO(
                            roomID: UUID(),
                            roomName: "Bedroom",
                            usdzURL: URL(string: "https://example.com/bedroom.usdz")!,
                            processedDate: Date()
                        ),
                        ScannedRoomDTO(
                            roomID: UUID(),
                            roomName: "Bathroom",
                            usdzURL: URL(string: "https://example.com/livingroom.usdz")!,
                            processedDate: Date()
                        ),
        ]
        
        sampleDTOs.forEach { dto in
            let room = ScannedRoom(dto: dto)
            context.insert(room)
        }
    }
}
