//
//  UserPermissionsInteractor.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-11.
//

import Foundation
import UserNotifications
import SwiftUI

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

// MARK: - UserPermissionsInteractor Protocol

protocol UserPermissionsInteractor: AnyObject {
    func resolveStatus(for permission: Permission)
    func request(permission: Permission)
}

// MARK: - RealUserPermissionsInteractor Implementation

final class RealUserPermissionsInteractor: UserPermissionsInteractor {
    private let appState: Store<AppState>
    private let openAppSettings: () -> Void
    private let notificationCenter: SystemNotificationsCenter

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
        let appState = appState
        
        switch permission {
        case .pushNotifications:
            Task { @MainActor in
                appState[keyPath] = await pushNotificationsPermissionStatus()
            }
        case .camera:
            break
        }
    }

    func request(permission: Permission) {
        switch permission {
        case .pushNotifications:
            Task {
                do {
                    let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
                    await MainActor.run {
                        self.appState[\.permissions.push] = granted ? .granted : .denied
                    }
                } catch {
                    await MainActor.run {
                        self.appState[\.permissions.push] = .denied
                    }
                }
            }
        case .camera:
            break
        }
    }
}

extension UNAuthorizationStatus {
    /// Maps UNAuthorizationStatus to our simpler PermissionStatus enum.
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

    func pushNotificationsPermissionStatus() async -> Permission.Status {
        return await notificationCenter
            .currentSettings()
            .authorizationStatus
            .mapToPermissionStatus()
    }

    func requestPushNotificationsPermission() async {
        let center = notificationCenter
        let isGranted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        appState[\.permissions.push] = isGranted ? .granted : .denied
    }
}

// MARK: - StubUserPermissionsInteractor

final class StubUserPermissionsInteractor: UserPermissionsInteractor {
    func resolveStatus(for permission: Permission) {}
    func request(permission: Permission) {}
}
