//
//  SampleData.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-12.
//

import Foundation

extension Scan {
    
    static let sample: Scan = {
        guard let modelURL = Bundle.main.url(forResource: "sample", withExtension: "usdz") else {
            fatalError("Unable to find sample.usdz in bundle.")
        }
        
        return Scan(
            id: UUID(),
            name: "Sample Scan",
            usdzURL: modelURL,
            processedDate: .now
        )
    }()
}

extension UploadTask {
    
    static let sample = UploadTask(
        id: UUID(),
        name: "Sample",
        imageURLs: [URL(string: "https://example.com/image1.jpg")!],
        createdAt: Date(),
        retryCount: 0,
        uploadStatus: .pendingUpload
    )
}
