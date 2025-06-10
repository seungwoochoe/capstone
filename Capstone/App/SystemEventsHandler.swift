//
//  SystemEventsHandler.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import SwiftUI
import Combine
import OSLog

protocol SystemEventsHandler {
    func sceneDidBecomeActive()
    func sceneWillResignActive()
    func handlePushRegistration(result: Result<Data, Error>)
    func appDidReceiveRemoteNotification(payload: [AnyHashable: Any]) async -> UIBackgroundFetchResult
}

struct RealSystemEventsHandler: SystemEventsHandler {
    
    private let container: DIContainer
    private let deepLinksHandler: DeepLinksHandler
    private let pushNotificationsHandler: PushNotificationsHandler
    private let pushTokenWebRepository: PushTokenWebRepository
    private let cancelBag = CancelBag()
    
    private let logger = Logger.forType(RealSystemEventsHandler.self)
    
    init(container: DIContainer,
         deepLinksHandler: DeepLinksHandler,
         pushNotificationsHandler: PushNotificationsHandler,
         pushTokenWebRepository: PushTokenWebRepository) {
        
        self.container = container
        self.deepLinksHandler = deepLinksHandler
        self.pushNotificationsHandler = pushNotificationsHandler
        self.pushTokenWebRepository = pushTokenWebRepository
        
        installPushNotificationsSubscriberOnLaunch()
    }
    
    private func installPushNotificationsSubscriberOnLaunch() {
        container.appState
            .updates(for: AppState.permissionKeyPath(for: .pushNotifications))
            .first(where: { $0 != .unknown })
            .sink { status in
                if status == .granted {
                    UIApplication.shared.registerForRemoteNotifications()
                    logger.info("Called UIApplication.shared.registerForRemoteNotifications (installPushNotificationsSubscriberOnLaunch).")
                }
            }
            .store(in: cancelBag)
    }
    
    func sceneDidBecomeActive() {
        container.appState[\.system.isActive] = true
        container.interactors.userPermissions.resolveStatus(for: .pushNotifications)
        container.interactors.userPermissions.resolveStatus(for: .camera)
        
        if container.appState[\.auth.isSignedIn],
           container.appState[\.permissions.push] == .granted {
            UIApplication.shared.registerForRemoteNotifications()
            logger.debug("Called UIApplication.shared.registerForRemoteNotifications (sceneDidBecomeActive).")
        }
        
        Task {
            await container.interactors.scanInteractor.uploadPendingTasks()
        }
    }
    
    func sceneWillResignActive() {
        container.appState[\.system.isActive] = false
    }
    
    func handlePushRegistration(result: Result<Data, Error>) {
        switch result {
        case .success(let deviceToken):
            let tokenHex = deviceToken.map { String(format: "%02x", $0) }.joined()
            logger.info("Received device token: \(tokenHex, privacy: .private).")
            Task {
                do {
                    let endpointArn = try await pushTokenWebRepository.registerPushToken(deviceToken)
                    Defaults[.pushEndpointArn] = endpointArn
                    logger.info("Successfully registered push token. EndpointArn: \(endpointArn, privacy: .public).")
                } catch {
                    logger.error("Failed to register push token: \(error.localizedDescription, privacy: .public).")
                }
            }
        case .failure(let error):
            logger.error("Failed to register for remote notifications: \(error.localizedDescription, privacy: .public).")
        }
    }
    
    func appDidReceiveRemoteNotification(payload: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        logger.debug("App did receive remote notification payload: \(payload).")
        if let scanID = payload["scanID"] as? String {
            logger.info("Remote notification contains scanID: \(scanID, privacy: .public).")
            await container.interactors.scanInteractor.handlePush(scanID: scanID)
            return .newData
        }
        logger.debug("Remote notification payload did not contain a scanID.")
        return .noData
    }
}
