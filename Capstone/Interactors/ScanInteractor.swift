//
//  ScanInteractor.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import SwiftUI
import OSLog

// MARK: - ScanInteractor

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

// MARK: - RealScanInteractor

struct RealScanInteractor: ScanInteractor {
    
    private let webRepository: ScanWebRepository
    private let uploadTaskLocalRepository: UploadTaskLocalRepository
    private let scanLocalRepository: ScanLocalRepository
    private let fileManager: FileManager
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: #file)
    
    init(webRepository: ScanWebRepository,
         uploadTaskLocalRepository: UploadTaskLocalRepository,
         scanLocalRepository: ScanLocalRepository,
         fileManager: FileManager) {
        self.webRepository = webRepository
        self.uploadTaskLocalRepository = uploadTaskLocalRepository
        self.scanLocalRepository = scanLocalRepository
        self.fileManager = fileManager
    }
    
    func fetchUploadTasks() async throws -> [UploadTask] {
        try await uploadTaskLocalRepository.fetch()
    }
    
    func fetchScans() async throws -> [Scan] {
        try await scanLocalRepository.fetch()
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
        
        try await uploadTaskLocalRepository.store(uploadTask)
        return uploadTask
    }
    
    func upload(_ uploadTask: UploadTask) async throws {
        var mutableTask = uploadTask
        mutableTask.uploadStatus = .uploading
        try await uploadTaskLocalRepository.update(mutableTask)
        
        do {
            let imageDatas = try uploadTask.imageURLs.map { try Data(contentsOf: $0) }
            
            _ = try await webRepository.uploadScan(id: uploadTask.id.uuidString,
                                                   images: imageDatas)
            
            mutableTask.uploadStatus = .waitingForResult
            try await uploadTaskLocalRepository.update(mutableTask)
        } catch {
            logger.error("Upload failed: \(error)")
            mutableTask.retryCount += 1
            mutableTask.uploadStatus = .failedUpload
            try await uploadTaskLocalRepository.update(mutableTask)
            throw error
        }
    }
    
    // Push notification entry point
    
    func handlePush(scanID: String) async {
        do {
            try await fetchResult(for: scanID)
        } catch {
            logger.error("Failed to fetch result for scanID \(scanID): \(error)")
        }
    }
    
    // Delete
    
    func delete(_ uploadTask: UploadTask) async throws {
        try await uploadTaskLocalRepository.delete(uploadTask)
        try deleteImagesFromDisk(for: uploadTask)
    }
    
    func delete(_ scan: Scan) async throws {
        try await scanLocalRepository.delete(scan)
    }
    
    func deleteAll() async throws {
        for task in try await uploadTaskLocalRepository.fetch() {
            try await delete(task)
        }
        for scan in try await scanLocalRepository.fetch() {
            try await delete(scan)
        }
    }
    
    // MARK: - Private helpers
    
    private func fetchResult(for scanID: String) async throws {
        
        guard var uploadTask = try await uploadTaskLocalRepository
            .fetch().first(where: { $0.id.uuidString == scanID }) else {
            logger.info("No upload task found for scanID \(scanID)")
            return
        }
        
        // 1) Poll task state
        let response = try await webRepository.fetchTask(id: scanID)
        
        guard response.status == "finished" else {
            if response.status == "failed" {
                uploadTask.uploadStatus = .failedProcessing
                try? await uploadTaskLocalRepository.update(uploadTask)
            }
            return      // still processing
        }
        
        // 2) Download the .usdz
        guard let usdzURL = response.usdzURL else { return }
        let localUSDZ = try await webRepository.downloadUSDZ(from: usdzURL)
        
        // 3) Persist as Scan
        let scan = Scan(id: uploadTask.id,
                        name: uploadTask.name,
                        usdzURL: localUSDZ,
                        processedDate: response.processedAt ?? Date())
        try await scanLocalRepository.store(scan)
        
        // 4) Delete the uploadTask
        try await delete(uploadTask)
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
