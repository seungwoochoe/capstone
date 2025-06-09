//
//  DeepLinksHandler.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-11.
//

import Foundation
import OSLog

enum DeepLink: Equatable {
    
    case showScan(scanID: String)
    
    init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              components.host == "www.example.com",
              let queryItems = components.queryItems
        else {
            return nil
        }
        
        if let item = queryItems.first(where: { $0.name == "scanID" }),
           let scanID = item.value {
            self = .showScan(scanID: scanID)
            return
        }
        return nil
    }
}

// MARK: - DeepLinksHandler

protocol DeepLinksHandler {
    func open(deepLink: DeepLink)
}

struct RealDeepLinksHandler: DeepLinksHandler {
    
    private let container: DIContainer
    private let logger = Logger.forType(RealDeepLinksHandler.self)
    
    init(diContainer: DIContainer) {
        self.container = diContainer
    }
    
    func open(deepLink: DeepLink) {
        switch deepLink {
        case .showScan(let scanID):
            logger.info("Handling showScan deep link for ID: \(scanID, privacy: .public)")
            let routeToScan = {
                guard let uuid = UUID(uuidString: scanID) else {
                    logger.error("Invalid scanID UUID string: \(scanID, privacy: .public)")
                    return
                }
                self.container.appState.bulkUpdate {
                    $0.routing.selectedScanID = uuid
                    logger.debug("Updated selectedScanID in app state to: \(uuid.uuidString, privacy: .public)")
                }
            }
            
            let defaultRouting = AppState.ViewRouting()
            if container.appState.value.routing != defaultRouting {
                logger.debug("Current routing is not default, skipping deep link handling")
                return
            }
            
            Task { @MainActor in
                routeToScan()
                logger.info("Deep link navigation to scan view executed")
            }
        }
    }
}
