//
//  AppEnvironment.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import SwiftUI
import SwiftData

@MainActor
struct AppEnvironment {
    let isRunningTests: Bool
    let diContainer: DIContainer
    let modelContainer: ModelContainer
    let systemEventsHandler: SystemEventsHandler
}

extension AppEnvironment {
    
    static func bootstrap() -> AppEnvironment {
        // App state and persistence.
        let appState = Store<AppState>(AppState())
        let modelContainer = (try? ModelContainer.appModelContainer()) ?? ModelContainer.stub
        
        // Create a URL session.
        let session = URLSession(configuration: .default)
        
        // Set up web repositories.
        let roomWebRepo = RoomScanWebRepository(session: session)
        let authWebRepo = AuthWebRepository(session: session)
        
        // Set up persistence repository.
        let roomDBRepository = RoomScanPersistenceRepository(modelContainer: modelContainer)
        
        // Initialize interactors.
        let scanRoomInteractor = ScanRoomInteractor(webRepository: roomWebRepo,
                                                      persistenceRepository: roomDBRepository)
        let scannedRoomsInteractor = ScannedRoomsInteractor(persistenceRepository: roomDBRepository)
        let authInteractor = AuthInteractor(webRepository: authWebRepo, keychainService: KeychainService())
        let userPermissions = UserPermissionsInteractor
        
        let interactors = DIContainer.Interactors(
            scanRoom: scanRoomInteractor,
            scannedRooms: scannedRoomsInteractor,
            auth: authInteractor,
            userPermissions: u
        )
        
        let diContainer = DIContainer(appState: appState, interactors: interactors)
        
        // Set up push notifications and deep linking handlers.
        let deepLinksHandler = RealDeepLinksHandler(container: diContainer)
        let pushNotificationsHandler = RealPushNotificationsHandler(deepLinksHandler: deepLinksHandler)
        let systemEventsHandler = RealSystemEventsHandler(
            container: diContainer,
            deepLinksHandler: deepLinksHandler,
            pushNotificationsHandler: pushNotificationsHandler,
            pushTokenWebRepository: authWebRepo // placeholder for push token repo
        )
        
        return AppEnvironment(diContainer: diContainer,
                              modelContainer: modelContainer,
                              systemEventsHandler: systemEventsHandler)
    }
}
