//
//  PushNotificationsHandler.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-11.
//

import UserNotifications

protocol PushNotificationsHandler { }

final class RealPushNotificationsHandler: NSObject, PushNotificationsHandler {
    
    private let scanInteractor: ScanInteractor
    private let deepLinksHandler: DeepLinksHandler
    
    init(scanInteractor: ScanInteractor, deepLinksHandler: DeepLinksHandler) {
        self.scanInteractor = scanInteractor
        self.deepLinksHandler = deepLinksHandler
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension RealPushNotificationsHandler: UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler:
                                @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        handleNotification(userInfo: userInfo, completionHandler: completionHandler)
    }
    
    func handleNotification(userInfo: [AnyHashable : Any], completionHandler: @escaping () -> Void) {
        guard let scanID = userInfo["scanID"] as? String else { completionHandler(); return }
        
        Task { @MainActor in
            await scanInteractor.handlePush(scanID: scanID)
            deepLinksHandler.open(deepLink: .showScan(scanID: scanID))
            completionHandler()
        }
    }
}
