//
//  Helpers.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-11.
//

import Foundation
import Combine
import SwiftData

extension ProcessInfo {
    var isRunningTests: Bool {
        environment["XCTestConfigurationFilePath"] != nil
    }
}

extension Result {
    var isSuccess: Bool {
        switch self {
        case .success: return true
        case .failure: return false
        }
    }
}

enum SCApp {
    static let name = Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as! String
    static let licence = Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as! String
    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
}

enum ModelContextError: Error {
    case notFound(id: UUID)
    case multipleResults(id: UUID, found: Int)
}

extension ModelContext {
    func existingModel<T>(for id: UUID) throws -> T? where T: PersistentModel, T.ID == UUID {
        let fetchDescriptor = FetchDescriptor<T>(
            predicate: #Predicate { $0.id == id }
        )
        let results = try fetch(fetchDescriptor)
        
        switch results.count {
        case 0:
            throw ModelContextError.notFound(id: id)
        case 1:
            return results[0]
        default:
            throw ModelContextError.multipleResults(id: id, found: results.count)
        }
    }
}

extension URL {
    func queryItem(named name: String) -> String? {
        URLComponents(url: self, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == name })?.value
    }
}

