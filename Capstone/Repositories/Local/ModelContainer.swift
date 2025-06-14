//
//  ModelContainer.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import SwiftData

extension ModelContainer {
    
    static func appModelContainer(inMemoryOnly: Bool = false)
    throws -> ModelContainer {
        let schema = Schema.appSchema
        let configuration = ModelConfiguration(inMemoryOnly ? "stub" : nil, schema: schema, isStoredInMemoryOnly: inMemoryOnly)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
    
    static var inMemory: ModelContainer {
        try! appModelContainer(inMemoryOnly: true)
    }
    
    var isStub: Bool {
        return configurations.first?.name == "stub"
    }
}
