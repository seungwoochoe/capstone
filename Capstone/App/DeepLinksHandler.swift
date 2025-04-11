//
//  DeepLinksHandler.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-11.
//

import Foundation

enum DeepLink: Equatable {
    
    case showScannedRoom(roomID: String)
    
    init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              components.host == "www.example.com",
              let queryItems = components.queryItems
        else {
            return nil
        }
        
        if let item = queryItems.first(where: { $0.name.lowercased() == "roomid" }),
           let roomID = item.value {
            self = .showScannedRoom(roomID: roomID)
            return
        }
        return nil
    }
}

@MainActor
protocol DeepLinksHandler {
    func open(deepLink: DeepLink)
}

struct RealDeepLinksHandler: DeepLinksHandler {
    
    private let container: DIContainer
    
    init(container: DIContainer) {
        self.container = container
    }
    
    func open(deepLink: DeepLink) {
        switch deepLink {
        case .showScannedRoom(let roomID):
            let routeToScannedRoom = {
                self.container.appState.bulkUpdate {
                    $0.routing.activeTab = .scannedRooms
                    $0.routing.selectedRoomID = roomID
                }
            }
            
            /*
             SwiftUI is unable to perform complex navigation involving
             simultaneous dismissal or older screens and presenting new ones.
             A work around is to perform the navigation in two steps:
             */
            let defaultRouting = AppState.ViewRouting()
            if container.appState.value.routing != defaultRouting {
                self.container.appState[\.routing] = defaultRouting
                let delay: DispatchTime = .now() + (ProcessInfo.processInfo.isRunningTests ? 0 : 1.5)
                DispatchQueue.main.asyncAfter(deadline: delay, execute: routeToScannedRoom)
            } else {
                routeToScannedRoom()
            }
        }
    }
}
