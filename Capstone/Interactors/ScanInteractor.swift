//
//  ScanInteractor.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import SwiftUI
import OSLog

// MARK: - Protocol

protocol ScanInteractor {
    func fetchUploadTasks() async throws -> [UploadTask]
    func fetchScans() async throws -> [Scan]
    func storeUploadTask(scanName: String, images: [UIImage]) async throws -> UploadTask
    func upload(_ uploadTask: UploadTask) async throws
    func delete(_ uploadTask: UploadTask) async throws
    func delete(_ scan: Scan) async throws
    func deleteAll() async throws
    func handlePush(scanID: String) async
}

// MARK: - Implementation

struct RealScanInteractor: ScanInteractor {
    
    let webRepository: ScanWebRepository
    let uploadTaskPersistenceRepository: UploadTaskDBRepository
    let scanPersistenceRepository: ScanDBRepository
    let fileManager: FileManager
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!,
                                category: "ScanInteractor")
    
    init(webRepository: ScanWebRepository,
         uploadTaskPersistenceRepository: UploadTaskDBRepository,
         scanPersistenceRepository: ScanDBRepository,
         fileManager: FileManager) {
        self.webRepository = webRepository
        self.uploadTaskPersistenceRepository = uploadTaskPersistenceRepository
        self.scanPersistenceRepository = scanPersistenceRepository
        self.fileManager = fileManager
    }
    
    func fetchUploadTasks() async throws -> [UploadTask] {
        try await uploadTaskPersistenceRepository.fetch()
    }
    
    func fetchScans() async throws -> [Scan] {
        try await scanPersistenceRepository.fetch()
    }
    
    func storeUploadTask(scanName: String, images: [UIImage]) async throws -> UploadTask {
        let taskID = UUID()
        let folderURL = try createFolder(for: taskID)
        let imageURLs = try saveImagesToDisk(images: images, in: folderURL)
        
        let uploadTask = UploadTask(id: taskID,
                                    name: scanName,
                                    imageURLs: imageURLs,
                                    createdAt: Date(),
                                    retryCount: 0,
                                    uploadStatus: .pendingUpload)
        
        try await uploadTaskPersistenceRepository.store(uploadTask)
        return uploadTask
    }
    
    func upload(_ uploadTask: UploadTask) async throws {
        var mutableTask = uploadTask
        mutableTask.uploadStatus = .uploading
        try await uploadTaskPersistenceRepository.update(mutableTask)
        
        do {
            let imageDatas = try uploadTask.imageURLs.map { try Data(contentsOf: $0) }
            let response = try await webRepository.uploadScan(id: uploadTask.id.uuidString,
                                                              name: uploadTask.name,
                                                              images: imageDatas)
            mutableTask.uploadStatus = .waitingForResult
            try await uploadTaskPersistenceRepository.update(mutableTask)
        } catch {
            logger.error("Upload failed: \(error, privacy: .public)")
            mutableTask.retryCount += 1
            mutableTask.uploadStatus = .failedUpload
            try await uploadTaskPersistenceRepository.update(mutableTask)
            throw error
        }
    }
    
    // Push notification entry point
    
    func handlePush(scanID: String) async {
        do {
            try await fetchResult(for: scanID)
        } catch {
            logger.error("Failed to fetch result for scanID \(scanID): \(error, privacy: .public)")
        }
    }
    
    // Delete
    
    func delete(_ uploadTask: UploadTask) async throws {
        try await uploadTaskPersistenceRepository.delete(uploadTask)
        try deleteImagesFromDisk(for: uploadTask)
    }
    
    func delete(_ scan: Scan) async throws {
        try await scanPersistenceRepository.delete(scan)
    }
    
    func deleteAll() async throws {
        for task in try await uploadTaskPersistenceRepository.fetch() {
            try await delete(task)
        }
        for scan in try await scanPersistenceRepository.fetch() {
            try await delete(scan)
        }
    }
    
    // MARK: - Private helpers
    
    private func fetchResult(for scanID: String) async throws {
        // Resolve optional matching UploadTask (by remoteID)
        let maybeTask = try await uploadTaskPersistenceRepository.fetch().first { $0.id.uuidString == scanID }
        
        // 1) Ask server for job state
        let dto = try await webRepository.fetchScan(id: scanID)
        
        guard dto.status == "finished" else {
            if dto.status == "failed" {
                if var t = maybeTask {
                    t.uploadStatus = .failedProcessing
                    try? await uploadTaskPersistenceRepository.update(t)
                }
            }
            return // still processing
        }
        
        // 2) Download the .usdz
        let localUSDZ = try await webRepository.downloadUSDZ(from: dto.usdzURL)
        
        // 3) Persist as Scan
        let scan = Scan(id: UUID(uuidString: dto.id) ?? .init(),
                        name: dto.name,
                        usdzURL: localUSDZ,
                        processedDate: dto.processedAt)
        try await scanPersistenceRepository.store(scan)
        
        // 4) Mark the uploadTask as finished (or delete it entirely)
        if var t = maybeTask {
            t.uploadStatus = .finished
            try await uploadTaskPersistenceRepository.update(t)
            // optionally: try await delete(t) to clean list
        }
    }
    
    // MARK: File‑system utilities
    
    private func createFolder(for id: UUID) throws -> URL {
        guard let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        let folder = docs.appendingPathComponent(id.uuidString)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
    
    private func saveImagesToDisk(images: [UIImage], in folderURL: URL) throws -> [URL] {
        try images.enumerated().compactMap { idx, img in
            guard let data = img.jpegData(compressionQuality: 0.3) else { return nil }
            let url = folderURL.appendingPathComponent("\(idx + 1).jpg")
            try data.write(to: url)
            return url
        }
    }
    
    private func deleteImagesFromDisk(for uploadTask: UploadTask) throws {
        guard let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let folder = docs.appendingPathComponent(uploadTask.id.uuidString)
        if fileManager.fileExists(atPath: folder.path) {
            try fileManager.removeItem(at: folder)
        }
    }
}

// MARK: - Stub

struct StubScanInteractor: ScanInteractor {
    func fetchUploadTasks() async throws -> [UploadTask] { [] }
    func fetchScans() async throws -> [Scan] { [] }
    func storeUploadTask(scanName: String, images: [UIImage]) async throws -> UploadTask { .sample }
    func upload(_ uploadTask: UploadTask) async throws { }
    func export(_ scan: Scan) async throws { }
    func delete(_ uploadTask: UploadTask) async throws { }
    func delete(_ scan: Scan) async throws { }
    func deleteAll() async throws { }
    func handlePush(scanID: String) async { }
}
