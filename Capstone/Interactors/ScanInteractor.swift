//
//  ScanInteractor.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import SwiftUI

// MARK: - Protocol

protocol ScanInteractor {
    func storeUploadTask(scanName: String, images: [UIImage]) async throws -> UploadTaskDTO
    func upload(uploadTaskDTO: UploadTaskDTO) async throws
    func delete(uploadTask: DBModel.UploadTask) async throws
    func delete(scan: DBModel.Scan) async throws
    func deleteAll() async throws
}

// MARK: - Actual Implementation

struct RealScanInteractor: ScanInteractor {
    
    let webRepository: ScanWebRepository
    let uploadTaskPersistenceRepository: UploadTaskDBRepository
    let scanPersistenceRepository: ScanDBRepository
    let fileManager: FileManager
    
    func storeUploadTask(scanName: String, images: [UIImage]) async throws -> UploadTaskDTO {
        let taskId = UUID()
        let folderURL = try createFolder(for: taskId)
        let imageURLs = try saveImagesToDisk(images: images, in: folderURL)
        
        let uploadTaskDTO = UploadTaskDTO(
            id: taskId,
            name: scanName,
            imageURLs: imageURLs,
            createdAt: Date(),
            retryCount: 0,
            uploadStatus: .pending
        )
        
        try await uploadTaskPersistenceRepository.store(uploadTaskDTO: uploadTaskDTO)
        return uploadTaskDTO
    }
    
    func upload(uploadTaskDTO: UploadTaskDTO) async throws {
        var imageDataArray: [Data] = []
        for url in uploadTaskDTO.imageURLs {
            let data = try Data(contentsOf: url)
            imageDataArray.append(data)
        }
        
        do {
            let response = try await webRepository.uploadScan(scanName: uploadTaskDTO.name, imageData: imageDataArray)
            print("Upload succeeded: \(response)")
            
            // Update task status to succeeded.
            let updatedTaskDTO = UploadTaskDTO(
                id: uploadTaskDTO.id,
                name: uploadTaskDTO.name,
                imageURLs: uploadTaskDTO.imageURLs,
                createdAt: uploadTaskDTO.createdAt,
                retryCount: uploadTaskDTO.retryCount,
                uploadStatus: .succeeded
            )

            try await uploadTaskPersistenceRepository.update(uploadTaskDTO: updatedTaskDTO, for: uploadTaskDTO.id)
        } catch {
            print("Upload failed: \(error)")
            
            // Update with a failed status and increment the retry count.
            let updatedTaskDTO = UploadTaskDTO(
                id: uploadTaskDTO.id,
                name: uploadTaskDTO.name,
                imageURLs: uploadTaskDTO.imageURLs,
                createdAt: uploadTaskDTO.createdAt,
                retryCount: uploadTaskDTO.retryCount + 1,
                uploadStatus: .failed
            )
            
            try await uploadTaskPersistenceRepository.update(uploadTaskDTO: updatedTaskDTO, for: uploadTaskDTO.id)
            
            // TODO: Schedule a retry.
        }
    }
    
    func processPendingUploads() async {
        do {
            let pendingTasks = try await uploadTaskPersistenceRepository.fetchPendingUploadTasks()
            for task in pendingTasks {
                try await upload(uploadTaskDTO: task)
            }
        } catch {
            print("Error processing pending uploads: \(error)")
        }
    }
    
    func delete(uploadTask: DBModel.UploadTask) async throws {
        try await uploadTaskPersistenceRepository.delete(uploadTaskID: uploadTask.id)
        try deleteImagesFromDisk(for: uploadTask)
    }
    
    func delete(scan: DBModel.Scan) async throws {
        try await scanPersistenceRepository.delete(scanID: scan.id)
    }
    
    func deleteAll() async throws {
        let uploadTasks = try await uploadTaskPersistenceRepository.fetchPendingUploadTasks()
        let scans = try await scanPersistenceRepository.fetchAllScans()
        
        for uploadTask in uploadTasks {
            try await delete(uploadTask: DBModel.UploadTask(dto: uploadTask))
        }
        
        for scan in scans {
            try await delete(scan: DBModel.Scan(dto: scan))
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
        for image in images {
            guard let imageData = image.jpegData(compressionQuality: 0.8) else { continue }
            let uniqueName = UUID().uuidString
            let fileURL = folderURL.appendingPathComponent("upload_\(uniqueName).jpg")
            try imageData.write(to: fileURL)
            urls.append(fileURL)
        }
        return urls
    }
    
    private func deleteImagesFromDisk(for uploadTask: DBModel.UploadTask) throws {
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
    
    func storeUploadTask(scanName: String, images: [UIImage]) async throws -> UploadTaskDTO {
        return .sample
    }
    
    func upload(uploadTaskDTO: UploadTaskDTO) async throws {
        
    }
    
    func delete(uploadTask: DBModel.UploadTask) async throws {
        
    }
    
    func delete(scan: DBModel.Scan) async throws {
        
    }
    
    func deleteAll() async throws {
        
    }
}
