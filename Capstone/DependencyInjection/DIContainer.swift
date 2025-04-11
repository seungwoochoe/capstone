//
//  DIContainer.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import SwiftUI
import SwiftData

struct DIContainer {
    let appState: Store<AppState>
    let interactors: Interactors

    init(appState: Store<AppState> = .init(AppState()), interactors: Interactors) {
        self.appState = appState
        self.interactors = interactors
    }

    init(appState: AppState, interactors: Interactors) {
        self.init(appState: Store<AppState>(appState), interactors: interactors)
    }
}

extension DIContainer {
    // MARK: - Web Repositories
    struct WebRepositories {
        let roomScan: RoomScanWebRepository
        let auth: AuthWebRepository
    }
    
    // MARK: - Database Repositories
    struct DBRepositories {
        let roomScan: RoomScanPersistenceRepository
    }
    
    // MARK: - Interactors
    struct Interactors {
        let scanRoom: ScanRoomInteractor
        let scannedRooms: ScannedRoomsInteractor
        let auth: AuthInteractor
        let userPermissions: UserPermissionsInteractor

        /// Stub implementations for testing or preview purposes.
        static var stub: Self {
            .init(
                scanRoom: StubScanRoomInteractor(),
                scannedRooms: StubScannedRoomsInteractor(),
                auth: StubAuthInteractor(),
                userPermissions: StubUserPermissionsInteractor()
            )
        }
    }
}

extension EnvironmentValues {
    @Entry var injected: DIContainer = DIContainer(appState: AppState(), interactors: .stub)
}

extension View {
    func inject(_ container: DIContainer) -> some View {
        self.environment(\.injected, container)
    }
}
