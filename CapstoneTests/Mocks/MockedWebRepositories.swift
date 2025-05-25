//
//  MockedWebRepositories.swift
//  CapstoneTests
//
//  Created by Seungwoo Choe on 2025-05-17.
//

// MARK: - PushTokenWebRepository

import Foundation
@testable import Capstone

class TestWebRepository: WebRepository {
    let session: URLSession = .mockedResponsesOnly
    let baseURL = "https://test.com"
}

final class MockedScanWebRepository: TestWebRepository, Mock, ScanWebRepository {

    enum Action: Equatable {
        case uploadScan(id: String, name: String, imagesCount: Int)
        case fetchScan(id: String)
        case downloadUSDZ(url: URL)
    }

    var actions = MockActions<Action>(expected: [])

    var uploadScanResponses: [Result<UploadResponse, Error>] = []
    var fetchScanResponses: [Result<ScanResponse, Error>] = []
    var downloadUSDZResponses: [Result<URL, Error>] = []

    func uploadScan(id: String, name: String, images: [Data]) async throws -> UploadResponse {
        register(.uploadScan(id: id, name: name, imagesCount: images.count))
        guard !uploadScanResponses.isEmpty else { throw MockError.valueNotSet }
        return try uploadScanResponses.removeFirst().get()
    }

    func fetchScan(id: String) async throws -> ScanResponse {
        register(.fetchScan(id: id))
        guard !fetchScanResponses.isEmpty else { throw MockError.valueNotSet }
        return try fetchScanResponses.removeFirst().get()
    }

    func downloadUSDZ(from url: URL) async throws -> URL {
        register(.downloadUSDZ(url: url))
        guard !downloadUSDZResponses.isEmpty else { throw MockError.valueNotSet }
        return try downloadUSDZResponses.removeFirst().get()
    }
}

final class MockedPushTokenWebRepository: TestWebRepository, Mock, PushTokenWebRepository {
    
    enum Action: Equatable {
        case register(Data)
    }
    let actions: MockActions<Action>

    init(expected: [Action]) {
        self.actions = MockActions<Action>(expected: expected)
    }
    
    func registerPushToken(_ token: Data) async throws {
        register(.register(token))
    }
}
