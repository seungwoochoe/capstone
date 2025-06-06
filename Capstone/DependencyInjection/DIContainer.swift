//
//  DIContainer.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import SwiftUI

struct DIContainer {
    let appState: Store<AppState>
    let interactors: Interactors
    let services: Services
    
    init(appState: Store<AppState> = .init(AppState()), services: Services, interactors: Interactors) {
        self.appState = appState
        self.services = services
        self.interactors = interactors
    }
    
    init(appState: AppState, services: Services, interactors: Interactors) {
        self.init(appState: Store<AppState>(appState), services: services, interactors: interactors)
    }
}

extension DIContainer {
    
    struct LocalRepositories {
        let uploadTaskLocalRepository: UploadTaskLocalRepository
        let scanLocalRepository: ScanLocalRepository
    }
    
    struct WebRepositories {
        let scanWebRepository: ScanWebRepository
        let authWebRepository: AuthWebRepository
        let pushTokenWebRepository: PushTokenWebRepository
    }
    
    struct Services {
        let defaultsService: DefaultsService
        let keychainService: KeychainService
        
        static var stub: Self {
            .init(
                defaultsService: StubDefaultsService(),
                keychainService: StubKeychainService()
            )
        }
    }
    
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
    @Entry var injected: DIContainer = DIContainer(appState: AppState(), services: .stub, interactors: .stub)
}

extension View {
    func inject(_ container: DIContainer) -> some View {
        self.environment(\.injected, container)
    }
}
