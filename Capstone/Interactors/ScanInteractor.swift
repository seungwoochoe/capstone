//
//  ScanInteractor.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import SwiftUI

// MARK: - Protocol

protocol ScanInteractor {
    func storeUploadTask(scanName: String, images: [UIImage]) async throws
    func getStoredScans() async throws -> [DBModel.Scan]
    func delete(scan: DBModel.Scan) async throws
}

// MARK: - Actual Implementation

struct RealScanInteractor: ScanInteractor {
    
    let webRepository: ScanWebRepository
    let uploadTaskPersistenceRepository: UploadTaskDBRepository
    let scanPersistenceRepository: ScanDBRepository
    let fileManager: FileManager
    
    func storeUploadTask(scanName: String, images: [UIImage]) async throws {
        let imageURLs = try saveImagesToDisk(images: images)
        let taskDTO = UploadTaskDTO(
            id: UUID(),
            name: scanName,
            imageURLs: imageURLs,
            createdAt: Date(),
            retryCount: 0,
            uploadStatus: .pending
        )
        
        try await uploadTaskPersistenceRepository.store(uploadTaskDTO: taskDTO)
        try await upload(taskDTO: taskDTO)
    }
    
    private func saveImagesToDisk(images: [UIImage]) throws -> [URL] {
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(
                domain: "FileManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Could not locate documents directory"]
            )
        }
        
        var urls: [URL] = []
        for image in images {
            guard let imageData = image.jpegData(compressionQuality: 0.8) else { continue }
            let uuid = UUID().uuidString
            let fileURL = documentsURL.appendingPathComponent("upload_\(uuid).jpg")
            try imageData.write(to: fileURL)
            urls.append(fileURL)
        }
        return urls
    }
    
    func upload(taskDTO: UploadTaskDTO) async throws {
        var imageDataArray: [Data] = []
        for url in taskDTO.imageURLs {
            let data = try Data(contentsOf: url)
            imageDataArray.append(data)
        }
        
        do {
            let response = try await webRepository.uploadScan(scanName: taskDTO.name, imageData: imageDataArray)
            print("Upload succeeded: \(response)")
            
            // Update task status to succeeded.
            let updatedTaskDTO = UploadTaskDTO(
                id: taskDTO.id,
                name: taskDTO.name,
                imageURLs: taskDTO.imageURLs,
                createdAt: taskDTO.createdAt,
                retryCount: taskDTO.retryCount,
                uploadStatus: .succeeded
            )

            try await uploadTaskPersistenceRepository.update(uploadTaskDTO: updatedTaskDTO, for: taskDTO.id)
        } catch {
            print("Upload failed: \(error)")
            
            // Update with a failed status and increment the retry count.
            let updatedTaskDTO = UploadTaskDTO(
                id: taskDTO.id,
                name: taskDTO.name,
                imageURLs: taskDTO.imageURLs,
                createdAt: taskDTO.createdAt,
                retryCount: taskDTO.retryCount + 1,
                uploadStatus: .failed
            )
            
            try await uploadTaskPersistenceRepository.update(uploadTaskDTO: updatedTaskDTO, for: taskDTO.id)
            
            // TODO: Schedule a retry.
        }
    }
    
    func processPendingUploads() async {
        do {
            let pendingTasks = try await uploadTaskPersistenceRepository.fetchPendingUploadTasks()
            for task in pendingTasks {
                try await upload(taskDTO: task)
            }
        } catch {
            print("Error processing pending uploads: \(error)")
        }
    }
    
    func getStoredScans() async throws -> [DBModel.Scan] {
        let scanDTOs = try await scanPersistenceRepository.fetchAllScans()
        return scanDTOs.map { DBModel.Scan(dto: $0) }
    }
    
    func delete(scan: DBModel.Scan) async throws {
        try await scanPersistenceRepository.delete(scanID: scan.id)
    }
}

// MARK: - Stub

struct StubScanInteractor: ScanInteractor {
    func storeUploadTask(scanName: String, images: [UIImage]) async throws {
        
    }
    
    func getStoredScans() async throws -> [DBModel.Scan] {
        return []
    }
    
    func delete(scan: DBModel.Scan) async throws {
        
    }
}
