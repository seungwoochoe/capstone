//
//  SystemEventsHandler.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import UIKit
import Combine

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
                    // If the permission was granted on previous launch
                    // requesting the push token again:
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
    }

    func sceneWillResignActive() {
        container.appState[\.system.isActive] = false
    }

    func handlePushRegistration(result: Result<Data, Error>) {

    }

    func appDidReceiveRemoteNotification(payload: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
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
