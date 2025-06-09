//
//  UserPermissionsInteractor.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-11.
//

import SwiftUI
import AVFoundation
import OSLog

// MARK: - Permission Types

enum Permission {
    case pushNotifications
    case camera
    
    enum Status: Equatable {
        case unknown
        case notRequested
        case granted
        case denied
    }
}

// MARK: - SystemNotificationsCenter Protocol & Extension

protocol SystemNotificationsCenter {
    func currentSettings() async -> SystemNotificationsSettings
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
}

extension UNNotificationSettings: SystemNotificationsSettings { }
extension UNUserNotificationCenter: SystemNotificationsCenter {
    func currentSettings() async -> any SystemNotificationsSettings {
        return await notificationSettings()
    }
}

protocol SystemNotificationsSettings {
    var authorizationStatus: UNAuthorizationStatus { get }
}

// MARK: - UserPermissionsInteractor

protocol UserPermissionsInteractor: AnyObject {
    func resolveStatus(for permission: Permission)
    func request(permission: Permission) async throws
}

// MARK: - RealUserPermissionsInteractor

final class RealUserPermissionsInteractor: UserPermissionsInteractor {
    
    private let appState: Store<AppState>
    private let openAppSettings: () -> Void
    private let notificationCenter: SystemNotificationsCenter
    
    private let logger = Logger.forType(RealUserPermissionsInteractor.self)
    
    init(appState: Store<AppState>,
         notificationCenter: SystemNotificationsCenter = UNUserNotificationCenter.current(),
         openAppSettings: @escaping () -> Void) {
        self.appState = appState
        self.notificationCenter = notificationCenter
        self.openAppSettings = openAppSettings
    }
    
    func resolveStatus(for permission: Permission) {
        let keyPath = AppState.permissionKeyPath(for: permission)
        let currentStatus = appState[keyPath]
        guard currentStatus == .unknown else { return }
        
        logger.debug("Resolving permission status for \(String(describing: permission)).")
        
        switch permission {
        case .pushNotifications:
            Task { @MainActor in
                let status = await pushNotificationsPermissionStatus()
                appState[keyPath] = status
                logger.debug("Push notifications permission resolved to: \(String(describing: status)).")
            }
        case .camera:
            let status = cameraPermissionStatus()
            appState[keyPath] = status
            logger.debug("Camera permission resolved to: \(String(describing: status)).")
        }
    }
    
    func request(permission: Permission) async throws {
        switch permission {
        case .pushNotifications:
            logger.debug("Requesting push notifications permission.")
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                self.appState[\.permissions.push] = granted ? .granted : .denied
                logger.info("Push notifications permission \(granted ? "granted" : "denied").")
            }
        case .camera:
            logger.debug("Requesting camera access.")
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            await MainActor.run {
                appState[\.permissions.camera] = granted ? .granted : .denied
                logger.info("Camera permission \(granted ? "granted" : "denied").")
            }
        }
    }
}

extension UNAuthorizationStatus {
    func mapToPermissionStatus() -> Permission.Status {
        switch self {
        case .authorized:
            return .granted
        case .denied:
            return .denied
        case .notDetermined:
            return .unknown
        case .provisional, .ephemeral:
            return .unknown
        @unknown default:
            return .unknown
        }
    }
}

private extension RealUserPermissionsInteractor {
    
    func cameraPermissionStatus() -> Permission.Status {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            return .unknown
        case .authorized:
            return .granted
        default:
            return .denied
        }
    }
    
    func pushNotificationsPermissionStatus() async -> Permission.Status {
        return await notificationCenter
            .currentSettings()
            .authorizationStatus
            .mapToPermissionStatus()
    }
}

// MARK: - Stub

final class StubUserPermissionsInteractor: UserPermissionsInteractor {
    func resolveStatus(for permission: Permission) {}
    func request(permission: Permission) {}
}
