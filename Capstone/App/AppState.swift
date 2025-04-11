//
//  AppState.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-11.
//

import SwiftUI
import Combine

// MARK: - AppState

struct AppState: Equatable {
    var routing = Routing()
    var system = System()
    var permissions = Permissions()
}

extension AppState {
    struct Routing: Equatable {
        var scannedRooms = ScannedRoomsRouting()
        var roomDetailID: String? = nil // to indicate the selected room’s identifier

        struct ScannedRoomsRouting: Equatable {
            var searchQuery: String = ""
        }
    }
}

extension AppState {
    struct System: Equatable {
        var isActive: Bool = false
        var keyboardHeight: CGFloat = 0
    }
}

extension AppState {
    struct Permissions: Equatable {
        var push: PermissionStatus = .unknown
        var camera: PermissionStatus = .unknown
    }
}

/// A simple enum to represent permission statuses.
enum PermissionStatus: Equatable {
    case unknown
    case notRequested
    case granted
    case denied
}

// You can add Codable conformance or additional helpers if needed.
