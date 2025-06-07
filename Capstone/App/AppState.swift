//
//  AppState.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-11.
//

import Foundation

struct AppState: Equatable {
    var auth: Auth
    var routing = ViewRouting()
    var system = System()
    var permissions = Permissions()
    
    init(isSignedIn: Bool = false) {
        self.auth = Auth(isSignedIn: isSignedIn)
    }
}

// MARK: - Auth

extension AppState {
    struct Auth: Equatable {
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
    struct System: Equatable {
        var isActive: Bool = false
    }
}

// MARK: - Permissions

extension AppState {
    struct Permissions: Equatable {
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
