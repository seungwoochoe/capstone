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
        /*
         To see the deep linking in action:
         
         1. Launch the app in iOS 13.4 simulator (or newer)
         2. Subscribe on Push Notifications with "Allow Push" button
         3. Minimize the app
         4. Drag & drop "push_with_deeplink.apns" into the Simulator window
         5. Tap on the push notification
         
         Alternatively, just copy the code below before the "return" and launch:
         
         DispatchQueue.main.async {
         deepLinksHandler.open(deepLink: .showCountryFlag(alpha3Code: "AFG"))
         }
         */
        
        let appState = Store<AppState>(AppState())
        let session = configuredURLSession()
        let keychainService = configuredKeychainService()
        let modelContainer = configuredModelContainer()
        
        let webRepositories = configuredWebRepositories(session: session)
        let dbRepositories = configuredDBRepositories(modelContainer: modelContainer)
        let interactors = configuredInteractors(appState: appState,
                                                webRepositories: webRepositories,
                                                dbRepositories: dbRepositories,
                                                keychainService: keychainService)

        let diContainer = DIContainer(appState: appState, interactors: interactors)
        let deepLinksHandler = RealDeepLinksHandler(diContainer: diContainer)
        let pushNotificationsHandler = RealPushNotificationsHandler(deepLinksHandler: deepLinksHandler)
        let systemEventsHandler = RealSystemEventsHandler(container: diContainer,
                                                          deepLinksHandler: deepLinksHandler,
                                                          pushNotificationsHandler: pushNotificationsHandler,
                                                          pushTokenWebRepository: webRepositories.pushTokenWebRepository)

        return AppEnvironment(isRunningTests: ProcessInfo.processInfo.isRunningTests,
                              diContainer: diContainer,
                              modelContainer: modelContainer,
                              systemEventsHandler: systemEventsHandler)
    }
    
    private static func configuredURLSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 120
        configuration.waitsForConnectivity = true
        configuration.httpMaximumConnectionsPerHost = 5
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = .shared
        return URLSession(configuration: configuration)
    }
    
    private static func configuredModelContainer() -> ModelContainer {
        do {
            return try ModelContainer.appModelContainer()
        } catch {
            // Log the error
            return ModelContainer.stub
        }
    }
    
    private static func configuredKeychainService() -> KeychainService {
        return RealKeychainService()
    }
    
    private static func configuredWebRepositories(session: URLSession) -> DIContainer.WebRepositories {
        let scannedRoom = RealScannedRoomWebRepository(session: session)
        let authentication = RealAuthenticationWebRepository(session: session)
        let pushToken = RealPushTokenWebRepository(session: session)
        return .init(scannedRoomWebRepository: scannedRoom,
                     authenticationWebRepository: authentication,
                     pushTokenWebRepository: pushToken)
    }
    
    private static func configuredDBRepositories(modelContainer: ModelContainer) -> DIContainer.DBRepositories {
        let scanUploadTask: ScanUploadTaskDBRepository = RealScanUploadTaskDBRepository(modelContainer: modelContainer)
        let scannedRoom: ScannedRoomDBRepository = RealScannedRoomDBRepository(modelContainer: modelContainer)
        return .init(scanUploadTaskDBRepository: scanUploadTask,
                     scannedRoomDBRepository: scannedRoom)
    }
    
    private static func configuredInteractors(
        appState: Store<AppState>,
        webRepositories: DIContainer.WebRepositories,
        dbRepositories: DIContainer.DBRepositories,
        keychainService: KeychainService
    ) -> DIContainer.Interactors {
        let scanRoom: ScanRoomInteractor = RealScanRoomInteractor(scanUploadTaskDBRepository: dbRepositories.scanUploadTaskDBRepository)
        let scannedRooms: ScannedRoomsInteractor = RealScannedRoomsInteractor(webRepository: webRepositories.scannedRoomWebRepository, persistenceRepository: dbRepositories.scannedRoomDBRepository)
        let auth: AuthInteractor = RealAuthInteractor(webRepository: webRepositories.authenticationWebRepository, keychainService: keychainService)
        let userPermissions: UserPermissionsInteractor = RealUserPermissionsInteractor(appState: appState, openAppSettings: {
            URL(string: UIApplication.openSettingsURLString).flatMap {
                UIApplication.shared.open($0, options: [:], completionHandler: nil)
            }
        })
        return .init(scanRoom: scanRoom, scannedRooms: scannedRooms, auth: auth, userPermissions: userPermissions)
    }
}
