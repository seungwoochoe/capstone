//
//  ScanWebRepositoryTests.swift
//  CapstoneTests
//
//  Created by Seungwoo Choe on 2025-06-01.
//

import Foundation
import Testing
@testable import Capstone   // Replace “Capstone” with your actual module name

// MARK: - Helpers ------------------------------------------------------------

private let baseURL = "https://5otayh1ahj.execute-api.ap-northeast-2.amazonaws.com"

/// A 1×1-pixel JPEG (base64) to keep uploads as small as possible.
private let tinyJPEGData: Data = {
    let b64 =
    """
    /9j/4AAQSkZJRgABAQAASABIAAD/4QBMRXhpZgAATU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAAAaADAAQAAAABAAAAAQAAAAD/wAARCAABAAEDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9sAQwACAgICAgIDAgIDBQMDAwUGBQUFBQYIBgYGBgYICggICAgICAoKCgoKCgoKDAwMDAwMDg4ODg4PDw8PDw8PDw8P/9sAQwECAgIEBAQHBAQHEAsJCxAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQ/90ABAAB/9oADAMBAAIRAxEAPwD4vooor+Uz/fw//9k=
    """
    return Data(base64Encoded: b64)!
}()

// MARK: - Test Suite ---------------------------------------------------------

@Suite("ScanWebRepository Integration Tests (using real AWS)")
struct ScanWebRepositoryIntegrationTests {
    
    /// A single `RealScanWebRepository` instance pointed at your live backend.
    /// Since Swift Testing instantiates a fresh `Suite` for each `@Test` function,
    /// this will be recreated for every test and never share state.
    var repository = RealScanWebRepository(session: .shared, baseURL: baseURL)
    
    
    @Test("Uploading two tiny JPEGs should return true and set status → ready-for-processing")
    func testUploadThenFetchTask() async throws {
        // 1) Generate a fresh UUID string
        let taskId = UUID().uuidString
        
        // 2) Call `uploadScan(id:images:)` with two tiny JPEG blobs
        let didUpload = try await repository.uploadScan(
            id: taskId,
            images: [tinyJPEGData, tinyJPEGData]
        )
        #expect(didUpload == true)
        
        // 3) Immediately fetch the task. The backend Lambda sets status="ready-for-processing"
        let taskStatus: TaskStatusResponse = try await repository.fetchTask(id: taskId)
        
        // Verify returned ID matches, status is exactly "ready-for-processing",
        // and `usdzURL` is still nil (since no modelKey yet).
        #expect(taskStatus.id == taskId)
        #expect(taskStatus.status == "ready-for-processing")
        #expect(taskStatus.usdzURL == nil)
    }
    
    
    @Test("Fetching a nonexistent task ID should throw a 404 error")
    func testFetchNonexistentTaskThrows404() async throws {
        // Attempt to fetch something that should never exist.
        let bogusId = "this-does-not-exist-\(UUID().uuidString)"
        
        do {
            _ = try await repository.fetchTask(id: bogusId)
            // If we get here, the call unexpectedly succeeded.
            #expect(Bool(false), "fetchTask(…) unexpectedly succeeded for a nonexistent ID")
        } catch let err as APIError {
            switch err {
            case .httpCode(let code):
                #expect(code == 404, "Expected 404 but got \(code)")
            default:
                // Any other APIError means something else went wrong
                #expect(Bool(false), "Expected a 404 HTTP code, but received \(err)")
            }
        } catch {
            // If it isn’t an APIError, that’s also a failure.
            #expect(Bool(false), "Expected APIError.httpCode(404), but threw: \(error)")
        }
    }
}
