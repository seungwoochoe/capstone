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
        let scanWebRepository: ScanWebRepository
        let authenticationWebRepository: AuthenticationWebRepository
        let pushTokenWebRepository: PushTokenWebRepository
    }

    // MARK: - Database Repositories
    struct DBRepositories {
        let scanUploadTaskDBRepository: UploadTaskDBRepository
        let scanDBRepository: ScanDBRepository
    }

    // MARK: - Interactors
    struct Interactors {
        let scan: ScanInteractor
        let auth: AuthInteractor
        let userPermissions: UserPermissionsInteractor

        /// Stub implementations for testing or preview purposes.
        static var stub: Self {
            .init(
                scan: StubScanInteractor(),
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
