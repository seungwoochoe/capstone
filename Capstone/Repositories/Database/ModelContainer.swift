//
//  ModelContainer.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import SwiftData

extension ModelContainer {
    
    static func appModelContainer(inMemoryOnly: Bool = false,
                                  isStub: Bool = false)
    throws -> ModelContainer {
        let schema = Schema([Scan.self])
        let configuration = ModelConfiguration(isStub ? "stub" : nil, schema: schema, isStoredInMemoryOnly: inMemoryOnly)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
    
    static var stub: ModelContainer {
        try! appModelContainer(inMemoryOnly: true, isStub: true)
    }
    
    var isStub: Bool {
        return configurations.first?.name == "stub"
    }
}
