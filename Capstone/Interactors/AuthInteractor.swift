//
//  AuthInteractor.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import Foundation

// MARK: - AuthInteractor

protocol AuthInteractor {
    func makeHostedUISignInURL(state: String, nonce: String) -> URL
    func completeSignIn(authorizationCode: String) async throws
    func signOut() async throws
}

// MARK: - RealAuthInteractor

final class RealAuthInteractor: AuthInteractor {
    
    private let appState: Store<AppState>
    private let webRepository: AuthWebRepository
    private let keychainService: KeychainService
    private var defaultsService: DefaultsService
    
    init(appState: Store<AppState>,
         webRepository: AuthWebRepository,
         keychainService: KeychainService,
         defaultsService: DefaultsService) {
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
        
        try keychainService.saveAccessToken(authResponse.accessToken)
        try keychainService.saveRefreshToken(authResponse.refreshToken)
        
        let expirationDate = Date().addingTimeInterval(TimeInterval(authResponse.expiresIn))
        defaultsService[.tokenExpirationDate] = expirationDate
        defaultsService[.userID] = authResponse.userID
        
        Task { @MainActor in
            appState[\.auth.isSignedIn] = true
        }
    }
    
    func signOut() async throws {
        try keychainService.deleteTokens()
        
        defaultsService[.tokenExpirationDate] = Date.distantPast
        defaultsService[.userID] = nil
        
        Task { @MainActor in
            appState[\.auth.isSignedIn] = false
        }
    }
}

// MARK: - Stub

struct StubAuthInteractor: AuthInteractor {
    func completeSignIn(authorizationCode: String) async throws {}
    func makeHostedUISignInURL(state: String, nonce: String) -> URL { return URL(string: "")! }
    func signOut() async throws {}
}
