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
    func updateSortField(_ sortField: SortField) async
    func updateSortOrder(_ sortOrder: SortOrder) async
    func fetchUploadTasks() async throws
    func fetchScans() async throws
    func storeUploadTask(scanName: String, images: [UIImage]) async throws -> UploadTask
    func uploadPendingTasks() async
    func upload(_ uploadTask: UploadTask) async throws
    func delete(_ uploadTask: UploadTask) async throws
    func delete(_ scan: Scan) async throws
    func handlePush(scanID: String) async
}

// MARK: - RealScanInteractor

class RealScanInteractor: ScanInteractor {
    
    private let appState: Store<AppState>
    private let webRepository: ScanWebRepository
    private let uploadTaskLocalRepository: UploadTaskLocalRepository
    private let scanLocalRepository: ScanLocalRepository
    private var defaultsService: DefaultsService
    private let fileManager: FileManager
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: #file)
    
    init(appState: Store<AppState>,
         webRepository: ScanWebRepository,
         uploadTaskLocalRepository: UploadTaskLocalRepository,
         scanLocalRepository: ScanLocalRepository,
         defaultsService: DefaultsService,
         fileManager: FileManager) {
        self.appState = appState
        self.webRepository = webRepository
        self.uploadTaskLocalRepository = uploadTaskLocalRepository
        self.scanLocalRepository = scanLocalRepository
        self.defaultsService = defaultsService
        self.fileManager = fileManager
    }
    
    func updateSortField(_ sortField: SortField) async {
        defaultsService[.sortField] = sortField
        await MainActor.run {
            appState[\.sortField] = sortField
        }
    }
    
    func updateSortOrder(_ sortOrder: SortOrder) async {
        defaultsService[.sortOrder] = sortOrder
        await MainActor.run {
            appState[\.sortOrder] = sortOrder
        }
    }
    
    func fetchUploadTasks() async throws {
        try await publishUploadTasks()
    }
    
    func fetchScans() async throws {
        try await publishScans()
    }
    
    func storeUploadTask(scanName: String, images: [UIImage]) async throws -> UploadTask {
        let taskID = UUID()
        let imageURLs = try saveImagesToDisk(images: images, forTask: taskID)
        
        let uploadTask = UploadTask(id: taskID,
                                    name: scanName,
                                    imageURLs: imageURLs,
                                    createdAt: Date(),
                                    retryCount: 0,
                                    uploadStatus: .pendingUpload)
        
        try await uploadTaskLocalRepository.store(uploadTask)
        logger.info("Stored upload task \(uploadTask.id.uuidString, privacy: .public)")
        
        try await publishUploadTasks()
        return uploadTask
    }
    
    func uploadPendingTasks() async {
        do {
            let allTasks = try await uploadTaskLocalRepository.fetch()
            let tasksToUpload = allTasks.filter {
                $0.uploadStatus == .pendingUpload ||
                $0.uploadStatus == .failedUpload
            }
            logger.debug("Found \(tasksToUpload.count) tasks to upload")
            
            for task in tasksToUpload {
                do {
                    logger.debug("Uploading task \(task.id.uuidString, privacy: .public)")
                    try await upload(task)
                } catch {
                    logger.error("Failed uploading task \(task.id.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }
            logger.debug("Completed processing pending tasks")
        } catch {
            logger.error("Could not fetch upload tasks: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    func upload(_ uploadTask: UploadTask) async throws {
        var mutableTask = uploadTask
        mutableTask.uploadStatus = .uploading
        try await uploadTaskLocalRepository.update(mutableTask)
        
        do {
            logger.debug("Reading image data for upload task")
            let imageDatas = try uploadTask.imageURLs.map { url in
                try Data(contentsOf: url)
            }
            logger.debug("Uploading \(imageDatas.count) images to web repository for task \(uploadTask.id.uuidString, privacy: .public)")
            
            _ = try await webRepository.uploadScan(id: uploadTask.id.uuidString,
                                                   images: imageDatas)
            logger.info("Upload successful for task \(uploadTask.id.uuidString, privacy: .public)")
            
            mutableTask.uploadStatus = .waitingForResult
            try await uploadTaskLocalRepository.update(mutableTask)
            try await publishUploadTasks()
            
        } catch {
            logger.error("Upload failed for task \(uploadTask.id.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
            mutableTask.retryCount += 1
            mutableTask.uploadStatus = .failedUpload
            try await uploadTaskLocalRepository.update(mutableTask)
            try await publishUploadTasks()
            throw error
        }
    }
    
    func handlePush(scanID: String) async {
        do {
            try await fetchResult(for: scanID)
        } catch {
            logger.error("Failed to fetch result for scanID \(scanID, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
    
    func delete(_ uploadTask: UploadTask) async throws {
        try await uploadTaskLocalRepository.delete(uploadTask)
        try deleteImagesFromDisk(for: uploadTask)
        logger.info("Deleted upload task and images for \(uploadTask.id.uuidString, privacy: .public)")
        try await publishUploadTasks()
    }
    
    func delete(_ scan: Scan) async throws {
        try await scanLocalRepository.delete(scan)
        logger.info("Deleted scan \(scan.id.uuidString, privacy: .public)")
        try await publishScans()
    }
    
    // MARK: - Private helpers
    
    private func fetchResult(for scanID: String) async throws {
        logger.debug("Fetching result for scanID \(scanID, privacy: .public)")
        
        guard var uploadTask = try await uploadTaskLocalRepository
            .fetch().first(where: { $0.id.uuidString == scanID }) else {
            logger.info("No upload task found for scanID \(scanID, privacy: .public)")
            return
        }
        
        let response = try await webRepository.fetchTask(id: scanID)
        logger.debug("Received task status '\(response.status, privacy: .public)' for scanID \(scanID, privacy: .public)")
        
        guard response.status == "finished" else {
            if response.status == "failed" {
                uploadTask.uploadStatus = .failedProcessing
                try? await uploadTaskLocalRepository.update(uploadTask)
                try await publishUploadTasks()
                logger.error("Processing failed for scanID \(scanID, privacy: .public)")
            }
            return
        }
        
        guard let usdzURL = response.usdzURL else {
            logger.warning("No USDZ URL provided for finished scanID \(scanID, privacy: .public)")
            return
        }
        logger.debug("Downloading USDZ from \(usdzURL.absoluteString, privacy: .public) for scanID \(scanID, privacy: .public)")
        try await webRepository.downloadUSDZ(from: usdzURL, scanID: scanID)
        
        let scan = Scan(id: uploadTask.id,
                        name: uploadTask.name,
                        createdAt: response.createdAt ?? Date())
        try await scanLocalRepository.store(scan)
        logger.info("Stored scan record for \(scan.id.uuidString, privacy: .public)")
        try await publishScans()
        
        try await delete(uploadTask)
    }
    
    // MARK: File‑system utilities
    
    private func imagesFolderURL(for id: UUID) throws -> URL {
        guard let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            logger.error("Could not locate Documents directory for task \(id.uuidString, privacy: .public)")
            throw CocoaError(.fileNoSuchFile)
        }
        let folder = docs.appendingPathComponent(id.uuidString, isDirectory: true)
        
        if !fileManager.fileExists(atPath: folder.path) {
            try fileManager.createDirectory(at: folder,
                                            withIntermediateDirectories: true,
                                            attributes: nil)
            logger.debug("Created image folder at \(folder.path, privacy: .public)")
        }
        return folder
    }
    
    private func saveImagesToDisk(images: [UIImage], forTask id: UUID) throws -> [URL] {
        let folderURL = try imagesFolderURL(for: id)
        var savedURLs: [URL] = []
        
        for (index, image) in images.enumerated() {
            let filename = "\(index + 1).jpg"
            let fileURL = folderURL.appendingPathComponent(filename)
            
            guard let data = image.jpegData(compressionQuality: 0.3) else {
                logger.error("Could not encode image \(index) for task \(id.uuidString, privacy: .public)")
                continue
            }
            try data.write(to: fileURL, options: .atomic)
            savedURLs.append(fileURL)
        }
        logger.debug("Saved \(savedURLs.count) images to disk at \(folderURL.path)")
        return savedURLs
    }
    
    private func deleteImagesFromDisk(for uploadTask: UploadTask) throws {
        let folder = try imagesFolderURL(for: uploadTask.id)
        
        try fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
                    .filter { $0.pathExtension == "jpg" }
                    .forEach {
                        try fileManager.removeItem(at: $0)
                    }
        logger.debug("Deleted image folder at \(folder.path, privacy: .public)")
    }
    
    private func publishScans() async throws {
        let scans = try await scanLocalRepository.fetch()
        await MainActor.run {
            appState[\.scans] = scans
        }
        logger.debug("Published scans to app state")
    }
    
    private func publishUploadTasks() async throws {
        let tasks = try await uploadTaskLocalRepository.fetch()
        await MainActor.run {
            appState[\.uploadTasks] = tasks
        }
        logger.debug("Published upload tasks to app state")
    }
}

// MARK: - Stub

struct StubScanInteractor: ScanInteractor {
    func updateSortField(_ sortField: SortField) async {}
    func updateSortOrder(_ sortOrder: SortOrder) async {}
    func fetchUploadTasks() async throws {}
    func fetchScans() async throws {}
    func storeUploadTask(scanName: String, images: [UIImage]) async throws -> UploadTask { .sample }
    func upload(_ uploadTask: UploadTask) async throws {}
    func uploadPendingTasks() async {}
    func delete(_ uploadTask: UploadTask) async throws {}
    func delete(_ scan: Scan) async throws {}
    func handlePush(scanID: String) async {}
}
