//
//  AppState.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-11.
//

import Foundation

struct AppState {
    var auth: Auth
    var routing = ViewRouting()
    var system = System()
    var permissions = Permissions()
    
    var scans: [Scan] = []
    var uploadTasks: [UploadTask] = []
    
    init(isSignedIn: Bool = false) {
        self.auth = Auth(isSignedIn: isSignedIn)
    }
}

// MARK: - Auth

extension AppState {
    struct Auth {
        var isSignedIn: Bool
    }
}

// MARK: - Routing

extension AppState {
    struct ViewRouting: Equatable {
        var selectedScanID: UUID? = nil
    }
}

// MARK: - System State

extension AppState {
    struct System {
        var isActive: Bool = false
    }
}

// MARK: - Permissions

extension AppState {
    struct Permissions {
        var camera: Permission.Status = .unknown
        var push: Permission.Status = .unknown
    }
    
    static func permissionKeyPath(for permission: Permission) -> WritableKeyPath<AppState, Permission.Status> {
        let pathToPermissions = \AppState.permissions
        switch permission {
        case .camera:
            return pathToPermissions.appending(path: \.camera)
        case .pushNotifications:
            return pathToPermissions.appending(path: \.push)
        }
    }
}
