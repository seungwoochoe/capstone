//
//  LocalServerIntergartionTests.swift
//  CapstoneTests
//
//  Created by Seungwoo Choe on 2025-05-21.
//

import SwiftData
import Testing
import UIKit
@testable import Capstone

@Suite("Local server integration")
struct UploadTaskIntegrationTests {
    
    private let interactor: ScanInteractor
    
    init() {
        let modelContainer: ModelContainer = .inMemory
        let scanWebRepository = RealScanWebRepository(baseURL: "http://localhost:8000")
        let uploadTaskPersistenceRepository = RealUploadTaskDBRepository(modelContainer: modelContainer)
        let scanPersistenceRepository = RealScanDBRepository(modelContainer: modelContainer)
        self.interactor = RealScanInteractor(webRepository: scanWebRepository,
                                             uploadTaskPersistenceRepository: uploadTaskPersistenceRepository,
                                             scanPersistenceRepository: scanPersistenceRepository,
                                             fileManager: .default)
    }
    
    @Test("Store & upload moves to .waitingForResult")
    func storeAndUpload() async throws {
        let images = (1...3).compactMap { _ in UIImage(systemName:"doc") }
        let task = try await interactor.storeUploadTask(scanName: "demo", images: images)
        
        try await interactor.upload(task)
        
        let refreshed = try await interactor
            .fetchUploadTasks()
            .first{ $0.id == task.id }
        
        #expect(refreshed?.uploadStatus == .waitingForResult)
    }
}
