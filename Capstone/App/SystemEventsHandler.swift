//
//  SystemEventsHandler.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import UIKit
import Combine
import OSLog

@MainActor
protocol SystemEventsHandler {
    func sceneOpenURLContexts(_ urlContexts: Set<UIOpenURLContext>)
    func sceneDidBecomeActive()
    func sceneWillResignActive()
    func handlePushRegistration(result: Result<Data, Error>)
    func appDidReceiveRemoteNotification(payload: [AnyHashable: Any]) async -> UIBackgroundFetchResult
}

struct RealSystemEventsHandler: SystemEventsHandler {
    
    let container: DIContainer
    let deepLinksHandler: DeepLinksHandler
    let pushNotificationsHandler: PushNotificationsHandler
    let pushTokenWebRepository: PushTokenWebRepository
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: #file)
    private let cancelBag = CancelBag()
    
    init(container: DIContainer,
         deepLinksHandler: DeepLinksHandler,
         pushNotificationsHandler: PushNotificationsHandler,
         pushTokenWebRepository: PushTokenWebRepository) {
        
        self.container = container
        self.deepLinksHandler = deepLinksHandler
        self.pushNotificationsHandler = pushNotificationsHandler
        self.pushTokenWebRepository = pushTokenWebRepository
        
        installKeyboardHeightObserver()
        installPushNotificationsSubscriberOnLaunch()
    }
    
    private func installKeyboardHeightObserver() {
        let appState = container.appState
        NotificationCenter.default.keyboardHeightPublisher
            .sink { [appState] height in
                appState[\.system.keyboardHeight] = height
            }
            .store(in: cancelBag)
    }
    
    private func installPushNotificationsSubscriberOnLaunch() {
        weak var permissions = container.interactors.userPermissions
        container.appState
            .updates(for: AppState.permissionKeyPath(for: .pushNotifications))
            .first(where: { $0 != .unknown })
            .sink { status in
                if status == .granted {
                    // If the permission was granted on a previous launch,
                    // request the push token again:
                    permissions?.request(permission: .pushNotifications)
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
        
        if container.appState[\.permissions].camera != .granted {
            container.interactors.userPermissions.request(permission: .camera)
        }
        if container.appState[\.permissions].push == .granted {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    func sceneWillResignActive() {
        container.appState[\.system.isActive] = false
    }
    
    func handlePushRegistration(result: Result<Data, Error>) {
        logger.log("Handling push registration")
        switch result {
        case .success(let deviceToken):
            // Send deviceToken to the backend to get an endpointArn
            Task {
                do {
                    let endpointArn =
                    try await pushTokenWebRepository.registerPushToken(deviceToken)
                    Defaults[.pushEndpointArn] = endpointArn
                    logger.debug("Successfully registered push token. EndpointArn: \(endpointArn)")
                } catch {
                    // Log or handle error
                    logger.error("Failed to register push token: \(error)")
                }
            }
        case .failure(let error):
            // The system failed to register for remote notifications
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

// MARK: - Notifications

private extension NotificationCenter {
    var keyboardHeightPublisher: AnyPublisher<CGFloat, Never> {
        let willShow = publisher(for: UIApplication.keyboardWillShowNotification)
            .map { $0.keyboardHeight }
        let willHide = publisher(for: UIApplication.keyboardWillHideNotification)
            .map { _ in CGFloat(0) }
        return Publishers.Merge(willShow, willHide)
            .eraseToAnyPublisher()
    }
}

private extension Notification {
    var keyboardHeight: CGFloat {
        return (userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?
            .cgRectValue.height ?? 0
    }
}
