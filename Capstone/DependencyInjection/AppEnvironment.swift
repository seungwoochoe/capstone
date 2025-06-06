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
        
        let baseURL = "https://0lin00e8oe.execute-api.ap-northeast-2.amazonaws.com"
        let userPoolDomain = "capstone-auth.auth.ap-northeast-2.amazoncognito.com"
        let clientId = "4oliffdd79l5mmkibr801lcn16"
        let redirectUri = "capstone://auth/callback"
        
        let services = configuredServices()
        
        let appState = Store<AppState>(AppState(isSignedIn: services.defaultsService[.userID] != nil))
        let session = configuredURLSession()
        let fileManager = configuredFileManager()
        let modelContainer = configuredModelContainer()
        
        let authWebRepository = RealAuthenticationWebRepository(
            session: session,
            baseURL: baseURL,
            userPoolDomain: userPoolDomain,
            clientId: clientId,
            redirectUri: redirectUri
        )
        
        let accessTokenProvider = RealAccessTokenProvider(
            keychainService: services.keychainService,
            defaultsService: services.defaultsService,
            authWebRepository: authWebRepository
        )
        
        let scanWebRepository = RealScanWebRepository(
            session: session,
            baseURL: baseURL,
            accessTokenProvider: accessTokenProvider
        )
        
        let pushTokenWebRepository = RealPushTokenWebRepository(
            session: session,
            baseURL: baseURL,
            accessTokenProvider: accessTokenProvider
        )
        
        let webRepositories = DIContainer.WebRepositories(
            scanWebRepository: scanWebRepository,
            authWebRepository: authWebRepository,
            pushTokenWebRepository: pushTokenWebRepository
        )
        
        let localRepositories = configuredLocalRepositories(modelContainer: modelContainer)
        
        let interactors = configuredInteractors(
            appState: appState,
            webRepositories: webRepositories,
            localRepositories: localRepositories,
            fileManager: fileManager,
            keychainService: services.keychainService,
            defaultsService: services.defaultsService
        )
        
        let diContainer = DIContainer(
            appState: appState,
            services: services,
            interactors: interactors
        )
        
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
            let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: #file)
            logger.debug("Failed to initialize the ModelContainer: \(error)")
            return ModelContainer.inMemory
        }
    }
    
    private static func configuredServices() -> DIContainer.Services {
        let defaultsService = RealDefaultsService()
        let keychainService = RealKeychainService()
        return .init(
            defaultsService: defaultsService,
            keychainService: keychainService
        )
    }
    
    private static func configuredLocalRepositories(modelContainer: ModelContainer) -> DIContainer.LocalRepositories {
        let uploadTask: UploadTaskLocalRepository = RealUploadTaskLocalRepository(modelContainer: modelContainer)
        let scan: ScanLocalRepository = RealScanLocalRepository(modelContainer: modelContainer)
        return .init(
            uploadTaskLocalRepository: uploadTask,
            scanLocalRepository: scan
        )
    }
    
    private static func configuredInteractors(
        appState: Store<AppState>,
        webRepositories: DIContainer.WebRepositories,
        localRepositories: DIContainer.LocalRepositories,
        fileManager: FileManager,
        keychainService: KeychainService,
        defaultsService: DefaultsService
    ) -> DIContainer.Interactors {
        let scan: ScanInteractor = RealScanInteractor(
            webRepository: webRepositories.scanWebRepository,
            uploadTaskLocalRepository: localRepositories.uploadTaskLocalRepository,
            scanLocalRepository: localRepositories.scanLocalRepository,
            fileManager: fileManager
        )
        
        let auth: AuthInteractor = RealAuthInteractor(
            appState: appState,
            webRepository: webRepositories.authWebRepository,
            keychainService: keychainService,
            defaultsService: defaultsService
        )
        
        let userPermissions: UserPermissionsInteractor = RealUserPermissionsInteractor(
            appState: appState,
            openAppSettings: {
                URL(string: UIApplication.openSettingsURLString).flatMap {
                    UIApplication.shared.open($0, options: [:], completionHandler: nil)
                }
            }
        )
        
        return .init(
            scanInteractor: scan,
            authInteractor: auth,
            userPermissions: userPermissions
        )
    }
}
