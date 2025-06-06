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
        
        if let item = queryItems.first(where: { $0.name.lowercased() == "scanid" }),
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
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: #file)
    
    init(diContainer: DIContainer) {
        self.container = diContainer
    }
    
    func open(deepLink: DeepLink) {
        switch deepLink {
        case .showScan(let scanID):
            let routeToScan = {
                self.container.appState.bulkUpdate {
                    guard let scanID = UUID(uuidString: scanID) else {
                        logger.error("Failed to parse scanID: \(scanID)")
                        return
                    }
                    $0.routing.selectedScanID = scanID
                }
            }
            
            let defaultRouting = AppState.ViewRouting()
            if container.appState.value.routing != defaultRouting {
                self.container.appState[\.routing] = defaultRouting
                let delay: DispatchTime = .now() + (ProcessInfo.processInfo.isRunningTests ? 0 : 1.5)
                DispatchQueue.main.asyncAfter(deadline: delay, execute: routeToScan)
            } else {
                routeToScan()
            }
        }
    }
}
