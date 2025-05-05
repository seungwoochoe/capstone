//
//  AppSchema.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-12.
//

import SwiftData

enum Persistence { }

extension Schema {
    private static var actualVersion: Schema.Version = Version(1, 0, 0)

    static var appSchema: Schema {
        Schema([
            Persistence.UploadTask.self,
            Persistence.Scan.self,
        ], version: actualVersion)
    }
}
