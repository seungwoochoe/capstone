//
//  AppEnvironment.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import SwiftUI
import SwiftData
import OSLog

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
         deepLinksHandler.open(deepLink: .showScan(scanID: "Scan.sample.id.uuidString"))
         }
         */
        
        let baseURL = "https://0lin00e8oe.execute-api.ap-northeast-2.amazonaws.com"
        let userPoolDomain = "capstone-auth.auth.ap-northeast-2.amazoncognito.com"
        let clientId = "4oliffdd79l5mmkibr801lcn16"
        let redirectUri = "capstone://auth/callback"
        
        let services = configuredServices()
        let appState = Store<AppState>(AppState(isSignedIn: services.defaultsService[.userID] != nil))
        let session = configuredURLSession()
        let fileManager = configuredFileManager()
        
        let modelContainer = configuredModelContainer()
        let webRepositories = configuredWebRepositories(session: session,
                                                        baseURL: baseURL,
                                                        userPoolDomain: userPoolDomain,
                                                        clientId: clientId,
                                                        redirectUri: redirectUri)
        let dbRepositories = configuredDBRepositories(modelContainer: modelContainer)
        
        let interactors = configuredInteractors(
            appState: appState,
            webRepositories: webRepositories,
            dbRepositories: dbRepositories,
            fileManager: fileManager,
            keychainService: services.keychainService,
            defaultsService: services.defaultsService
        )
        
        let diContainer = DIContainer(appState: appState, services: services, interactors: interactors)
        let deepLinksHandler = RealDeepLinksHandler(diContainer: diContainer)
        let pushNotificationsHandler = RealPushNotificationsHandler(
            scanInteractor: interactors.scanInteractor,
            deepLinksHandler: deepLinksHandler
        )
        let systemEventsHandler = RealSystemEventsHandler(
            container: diContainer,
            deepLinksHandler: deepLinksHandler,
            pushNotificationsHandler: pushNotificationsHandler,
            pushTokenWebRepository: webRepositories.pushTokenWebRepository
        )
        
        return AppEnvironment(
            isRunningTests: ProcessInfo.processInfo.isRunningTests,
            diContainer: diContainer,
            modelContainer: modelContainer,
            systemEventsHandler: systemEventsHandler
        )
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
    
    private static func configuredFileManager() -> FileManager {
        return FileManager.default
    }
    
    private static func configuredModelContainer() -> ModelContainer {
        do {
            return try ModelContainer.appModelContainer()
        } catch {
            let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "AppEnvironment")
            logger.debug("Failed to initialize the ModelContainer: \(error)")
            return ModelContainer.inMemory
        }
    }
    
    private static func configuredServices() -> DIContainer.Services {
        let defaultsService = RealDefaultsService()
        let keychainService = RealKeychainService()
        return .init(defaultsService: defaultsService,
                     keychainService: keychainService)
    }
    private static func configuredKeychainService() -> KeychainService {
        return RealKeychainService()
    }
    
    private static func configuredDefaultsService() -> DefaultsService {
        return RealDefaultsService()
    }
    
    private static func configuredWebRepositories(session: URLSession, baseURL: String, userPoolDomain: String, clientId: String, redirectUri: String) -> DIContainer.WebRepositories {
        let scan = RealScanWebRepository(session: session, baseURL: baseURL)
        let authentication = RealAuthenticationWebRepository(session: session, baseURL: baseURL, userPoolDomain: userPoolDomain, clientId: clientId, redirectUri: redirectUri)
        let pushToken = RealPushTokenWebRepository(session: session, baseURL: baseURL)
        return .init(scanWebRepository: scan,
                     authWebRepository: authentication,
                     pushTokenWebRepository: pushToken)
    }
    
    private static func configuredDBRepositories(modelContainer: ModelContainer) -> DIContainer.DBRepositories {
        let uploadTask: UploadTaskDBRepository = RealUploadTaskDBRepository(modelContainer: modelContainer)
        let scan: ScanDBRepository = RealScanDBRepository(modelContainer: modelContainer)
        return .init(uploadTaskDBRepository: uploadTask,
                     scanDBRepository: scan)
    }
    
    private static func configuredInteractors(
        appState: Store<AppState>,
        webRepositories: DIContainer.WebRepositories,
        dbRepositories: DIContainer.DBRepositories,
        fileManager: FileManager,
        keychainService: KeychainService,
        defaultsService: DefaultsService
    ) -> DIContainer.Interactors {
        let scan: ScanInteractor = RealScanInteractor(webRepository: webRepositories.scanWebRepository, uploadTaskPersistenceRepository: dbRepositories.uploadTaskDBRepository, scanPersistenceRepository: dbRepositories.scanDBRepository, fileManager: fileManager)
        let auth: AuthInteractor = RealAuthInteractor(appState: appState, webRepository: webRepositories.authWebRepository, keychainService: keychainService, defaultsService: defaultsService)
        let userPermissions: UserPermissionsInteractor = RealUserPermissionsInteractor(appState: appState, openAppSettings: {
            URL(string: UIApplication.openSettingsURLString).flatMap {
                UIApplication.shared.open($0, options: [:], completionHandler: nil)
            }
        })
        return .init(scanInteractor: scan, authInteractor: auth, userPermissions: userPermissions)
    }
}
