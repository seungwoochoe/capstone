//
//  AuthInteractor.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import Foundation

protocol AuthInteractor {
    func makeHostedUISignInURL(state: String, nonce: String) -> URL
    func completeSignIn(authorizationCode: String) async throws
    func signOut() async throws
}

class RealAuthInteractor: AuthInteractor {
    
    let appState: Store<AppState>
    let webRepository: AuthWebRepository
    let keychainService: KeychainService
    var defaultsService: DefaultsService
    
    init(appState: Store<AppState>, webRepository: AuthWebRepository, keychainService: KeychainService, defaultsService: DefaultsService) {
        self.appState = appState
        self.webRepository = webRepository
        self.keychainService = keychainService
        self.defaultsService = defaultsService
    }
    
    func makeHostedUISignInURL(state: String, nonce: String) -> URL {
        return webRepository.makeHostedUISignInURL(state: state, nonce: nonce)
    }

    func completeSignIn(authorizationCode code: String) async throws {
        let authResponse = try await webRepository.exchange(code: code)
        try keychainService.save(token: authResponse.token)
        defaultsService[.userID] = authResponse.userID
        
        Task {
            await MainActor.run {
                appState[\.auth].isSignedIn = true
            }
        }
    }
    
    func signOut() async throws {
        try keychainService.deleteToken()
        defaultsService[.userID] = nil
        
        Task {
            await MainActor.run {
                appState[\.auth].isSignedIn = false
            }
        }
    }
}

struct StubAuthInteractor: AuthInteractor {
    func completeSignIn(authorizationCode: String) async throws {}
    func makeHostedUISignInURL(state: String, nonce: String) -> URL { return URL(string: "")! }
    func signOut() async throws {}
}
