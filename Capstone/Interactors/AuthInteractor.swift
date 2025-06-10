//
//  AuthInteractor.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import Foundation
import OSLog

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
    
    private let logger = Logger.forType(RealAuthInteractor.self)
    
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
        logger.debug("Creating Hosted UI sign-in URL.")
        return webRepository.makeHostedUISignInURL(state: state, nonce: nonce)
    }
    
    func completeSignIn(authorizationCode code: String) async throws {
        do {
            logger.debug("Exchanging authorization code for tokens.")
            let authResponse = try await webRepository.exchange(code: code)
            
            try keychainService.saveAccessToken(authResponse.accessToken)
            try keychainService.saveRefreshToken(authResponse.refreshToken)
            
            let expirationDate = Date().addingTimeInterval(TimeInterval(authResponse.expiresIn))
            defaultsService[.tokenExpirationDate] = expirationDate
            defaultsService[.userID] = authResponse.userID
            
            Task { @MainActor in
                appState[\.auth.isSignedIn] = true
            }
            logger.info("User signed in successfully.")
        } catch {
            logger.error("Sign-in failed: \(error.localizedDescription, privacy: .public).")
            throw error
        }
    }
    
    func signOut() async throws {
        do {
            try keychainService.deleteTokens()
            
            defaultsService[.tokenExpirationDate] = Date.distantPast
            defaultsService[.userID] = nil
            
            Task { @MainActor in
                appState[\.auth.isSignedIn] = false
            }
            logger.info("User signed out.")
        } catch {
            logger.error("Sign-out failed: \(error.localizedDescription, privacy: .public).")
            throw error
        }
    }
}

// MARK: - Stub

struct StubAuthInteractor: AuthInteractor {
    func completeSignIn(authorizationCode: String) async throws {}
    func makeHostedUISignInURL(state: String, nonce: String) -> URL { return URL(string: "")! }
    func signOut() async throws {}
}
