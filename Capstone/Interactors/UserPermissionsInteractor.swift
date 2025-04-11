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
    // Add other permissions as needed.
}

// MARK: - UserPermissionsInteractor Protocol

protocol UserPermissionsInteractor: AnyObject {
    func resolveStatus(for permission: Permission)
    func request(permission: Permission)
}

// MARK: - SystemNotificationsCenter Protocol & Extension

protocol SystemNotificationsCenter {
    func currentSettings() async -> UNNotificationSettings
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
}

extension UNUserNotificationCenter: SystemNotificationsCenter {
    func currentSettings() async -> UNNotificationSettings {
        await self.notificationSettings()
    }
    
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        // This call already exists on UNUserNotificationCenter;
        // wrap it to conform to our protocol.
        try await self.requestAuthorization(options: options)
    }
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
        switch permission {
        case .pushNotifications:
            Task { @MainActor in
                let settings = await notificationCenter.currentSettings()
                // Map UNAuthorizationStatus to your PermissionStatus enum.
                appState[\.permissions.push] = settings.authorizationStatus.mapToPermissionStatus()
            }
        case .camera:
            // Implement camera permission status resolution, e.g., using AVCaptureDevice.authorizationStatus(for:)
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
            // Implement camera permission request if necessary.
            break
        }
    }
}

extension UNAuthorizationStatus {
    /// Maps UNAuthorizationStatus to our simpler PermissionStatus enum.
    func mapToPermissionStatus() -> PermissionStatus {
        switch self {
        case .authorized:
            return .granted
        case .denied:
            return .denied
        case .notDetermined:
            return .notRequested
        case .provisional, .ephemeral:
            return .notRequested
        @unknown default:
            return .unknown
        }
    }
}

// MARK: - StubUserPermissionsInteractor Implementation

final class StubUserPermissionsInteractor: UserPermissionsInteractor {
    func resolveStatus(for permission: Permission) {
        // No-op stub; you might set the status to granted by default for testing.
    }
    
    func request(permission: Permission) {
        // No-op stub.
    }
}
