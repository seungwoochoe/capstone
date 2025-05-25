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
        let authWebRepository: AuthWebRepository
        let pushTokenWebRepository: PushTokenWebRepository
    }

    // MARK: - Database Repositories
    struct DBRepositories {
        let uploadTaskDBRepository: UploadTaskDBRepository
        let scanDBRepository: ScanDBRepository
    }

    // MARK: - Interactors
    struct Interactors {
        let scanInteractor: ScanInteractor
        let authInteractor: AuthInteractor
        let userPermissions: UserPermissionsInteractor

        // For testing and previews.
        static var stub: Self {
            .init(
                scanInteractor: StubScanInteractor(),
                authInteractor: StubAuthInteractor(),
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
