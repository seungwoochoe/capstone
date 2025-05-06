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
}

// MARK: - Actual Implementation

struct RealScanInteractor: ScanInteractor {
    
    let webRepository: ScanWebRepository
    let uploadTaskPersistenceRepository: UploadTaskDBRepository
    let scanPersistenceRepository: ScanDBRepository
    let fileManager: FileManager
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ScanInteractor")
    
    func fetchUploadTasks() async throws -> [UploadTask] {
        try await uploadTaskPersistenceRepository.fetch()
    }
    
    func fetchScans() async throws -> [Scan] {
        return [.sample]
//        try await scanPersistenceRepository.fetch()
    }
    
    func storeUploadTask(scanName: String, images: [UIImage]) async throws -> UploadTask {
        let taskId = UUID()
        let folderURL = try createFolder(for: taskId)
        let imageURLs = try saveImagesToDisk(images: images, in: folderURL)
        
        let uploadTask = UploadTask(
            id: taskId,
            name: scanName,
            imageURLs: imageURLs,
            createdAt: Date(),
            retryCount: 0,
            uploadStatus: .pending
        )
        
        try await uploadTaskPersistenceRepository.store(uploadTask)
        return uploadTask
    }
    
    func upload(_ uploadTask: UploadTask) async throws {
        var imageDataArray: [Data] = []
        for url in uploadTask.imageURLs {
            let data = try Data(contentsOf: url)
            imageDataArray.append(data)
        }
        
        do {
            let response = try await webRepository.uploadScan(scanName: uploadTask.name, imageData: imageDataArray)
            logger.debug("Upload succeeded: \(String(describing: response))")
            
            var uploadTask = uploadTask
            uploadTask.uploadStatus = .succeeded

            try await uploadTaskPersistenceRepository.update(uploadTask)
            
        } catch {
            logger.debug("Upload failed: \(error)")
            
            var uploadTask = uploadTask
            uploadTask.uploadStatus = .failed
            uploadTask.retryCount += 1
            
            try await uploadTaskPersistenceRepository.update(uploadTask)
        }
    }
    
    private func processPendingUploads() async {
        do {
            let pendingTasks = try await uploadTaskPersistenceRepository.fetch()
            for task in pendingTasks {
                try await upload(task)
            }
        } catch {
            logger.debug("Error processing pending uploads: \(error)")
        }
    }
    
    func delete(_ uploadTask: UploadTask) async throws {
        try await uploadTaskPersistenceRepository.delete(uploadTask)
        try deleteImagesFromDisk(for: uploadTask)
    }
    
    func delete(_ scan: Scan) async throws {
        try await scanPersistenceRepository.delete(scan)
    }
    
    func deleteAll() async throws {
        let uploadTasks = try await uploadTaskPersistenceRepository.fetch()
        let scans = try await scanPersistenceRepository.fetch()
        
        for uploadTask in uploadTasks {
            try await delete(uploadTask)
        }
        
        for scan in scans {
            try await delete(scan)
        }
    }
}

extension RealScanInteractor {
    private func createFolder(for id: UUID) throws -> URL {
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(
                domain: "FileManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Could not locate documents directory"]
            )
        }
        
        let folderURL = documentsURL.appendingPathComponent(id.uuidString)
        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
        return folderURL
    }
    
    private func saveImagesToDisk(images: [UIImage], in folderURL: URL) throws -> [URL] {
        var urls: [URL] = []
        for (idx, image) in images.enumerated() {
            guard let imageData = image.jpegData(compressionQuality: 0.3) else { continue }
            let fileURL = folderURL.appendingPathComponent("\(idx + 1).jpg")
            try imageData.write(to: fileURL)
            urls.append(fileURL)
        }
        return urls
    }
    
    private func deleteImagesFromDisk(for uploadTask: UploadTask) throws {
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(
                domain: "FileManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Could not locate documents directory"]
            )
        }
        let folderURL = documentsURL.appendingPathComponent(uploadTask.id.uuidString)
        if fileManager.fileExists(atPath: folderURL.path) {
            try fileManager.removeItem(at: folderURL)
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
}
