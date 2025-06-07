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
    func sceneOpenURLContexts(_ urlContexts: Set<UIOpenURLContext>)
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
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: #file)
    
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
                }
            }
            .store(in: cancelBag)
    }
    
    func sceneOpenURLContexts(_ urlContexts: Set<UIOpenURLContext>) {
        guard let url = urlContexts.first?.url else { return }
        handle(url: url)
    }
    
    private func handle(url: URL) {
        if url.host == "auth" && url.path == "/callback",
           let code = url.queryItem(named: "code") {
            Task {
                try? await container.interactors.authInteractor.completeSignIn(authorizationCode: code)
            }
            return  // Done ­– stop further routing
        }
        
        guard let deepLink = DeepLink(url: url) else { return }
        deepLinksHandler.open(deepLink: deepLink)
    }
    
    func sceneDidBecomeActive() {
        container.appState[\.system.isActive] = true
        container.interactors.userPermissions.resolveStatus(for: .pushNotifications)
        container.interactors.userPermissions.resolveStatus(for: .camera)
        
        if container.appState[\.permissions.push] == .granted {
            UIApplication.shared.registerForRemoteNotifications()
        }
        
        Task {
            await container.interactors.scanInteractor.uploadPendingTasks()
        }
    }
    
    func sceneWillResignActive() {
        container.appState[\.system.isActive] = false
    }
    
    func handlePushRegistration(result: Result<Data, Error>) {
        logger.log("Handling push registration…")
        switch result {
        case .success(let deviceToken):
            Task {
                do {
                    let endpointArn = try await pushTokenWebRepository.registerPushToken(deviceToken)
                    Defaults[.pushEndpointArn] = endpointArn
                    logger.debug("Successfully registered push token. EndpointArn: \(endpointArn)")
                } catch {
                    logger.error("Failed to register push token: \(error)")
                }
            }
        case .failure(let error):
            logger.error("Did fail to register for remote notifications: \(error)")
        }
    }
    
    func appDidReceiveRemoteNotification(payload: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        logger.log("App did receive remote notifictaion: \(payload)")
        if let taskId = payload["taskId"] as? String {
            await container.interactors.scanInteractor.handlePush(scanID: taskId)
            return .newData
        }
        return .noData
    }
}
