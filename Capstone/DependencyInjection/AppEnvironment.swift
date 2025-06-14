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
        
        let baseURL = "https://ew82om2ujg.execute-api.ap-northeast-2.amazonaws.com"
        let userPoolDomain = "capstone-auth.auth.ap-northeast-2.amazoncognito.com"
        let clientId = "1rhsfbm6627ga4lbhog4gsknbg"
        let redirectUri = "capstone://auth/callback"
        
        let services = configuredServices()
        
        let appState = Store<AppState>(AppState(
            isSignedIn: services.defaultsService[.userID] != nil,
            sortField: services.defaultsService[.sortField],
            sortOrder: services.defaultsService[.sortOrder]
        ))
        let session = configuredURLSession()
        let modelContainer = configuredModelContainer()
        
        let authWebRepository = RealAuthenticationWebRepository(
            session: session,
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
            accessTokenProvider: accessTokenProvider,
            defaultsService: services.defaultsService,
            fileManager: services.fileManager
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
            fileManager: services.fileManager,
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
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 120
        configuration.waitsForConnectivity = true
        configuration.requestCachePolicy = .useProtocolCachePolicy
        return URLSession(configuration: configuration)
    }
    
    private static func configuredModelContainer() -> ModelContainer {
        do {
            return try ModelContainer.appModelContainer()
        } catch {
            let logger = Logger.forType(AppEnvironment.self)
            logger.debug("Failed to initialize the ModelContainer: \(error)")
            return ModelContainer.inMemory
        }
    }
    
    private static func configuredServices() -> DIContainer.Services {
        let defaultsService = RealDefaultsService()
        let keychainService = RealKeychainService()
        let fileManager = FileManager.default
        
        return .init(
            defaultsService: defaultsService,
            keychainService: keychainService,
            fileManager: fileManager
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
        let scan = RealScanInteractor(
            appState: appState,
            webRepository: webRepositories.scanWebRepository,
            uploadTaskLocalRepository: localRepositories.uploadTaskLocalRepository,
            scanLocalRepository: localRepositories.scanLocalRepository,
            defaultsService: defaultsService,
            fileManager: fileManager
        )
        
        let auth = RealAuthInteractor(
            appState: appState,
            webRepository: webRepositories.authWebRepository,
            keychainService: keychainService,
            defaultsService: defaultsService
        )
        
        let userPermissions = RealUserPermissionsInteractor(
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
