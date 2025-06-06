//
//  AccessTokenProvider.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-06-06.
//

import Foundation
import OSLog

enum TokenError: Error {
    case missingAccessToken
    case noRefreshToken
}

// MARK: - AccessTokenProvider

protocol AccessTokenProvider {
    func validAccessToken() async throws -> String
}

// MARK: - RealAccessTokenProvider

final class RealAccessTokenProvider: AccessTokenProvider {
    
    private let keychain: KeychainService
    private var defaults: DefaultsService
    private let authWebRepository: AuthWebRepository
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: #file)

    init(keychainService: KeychainService, defaultsService: DefaultsService, authWebRepository: AuthWebRepository) {
        self.keychain = keychainService
        self.defaults = defaultsService
        self.authWebRepository = authWebRepository
    }

    func validAccessToken() async throws -> String {
        let now = Date()

        // If we have a cached expiration date in the future, read the access token and return it.
        if defaults[.tokenExpirationDate] > now {
            guard let token = try keychain.getAccessToken() else {
                logger.error("No access token found in Keychain.")
                throw TokenError.missingAccessToken
            }
            return token
        }

        // Token is expired. Attempt to refresh using the stored refresh token.
        guard let refreshToken = try keychain.getRefreshToken() else {
            logger.error("No refresh token available; user must sign in again.")
            throw TokenError.noRefreshToken
        }

        let newAuthResponse = try await authWebRepository.refreshTokens(using: refreshToken)
        let newExpiry = Date().addingTimeInterval(TimeInterval(newAuthResponse.expiresIn))

        try keychain.saveAccessToken(newAuthResponse.accessToken)
        try keychain.saveRefreshToken(newAuthResponse.refreshToken)
        defaults[.tokenExpirationDate] = newExpiry

        logger.debug("Successfully refreshed access token; new expiry: \(newExpiry).")

        return newAuthResponse.accessToken
    }
}

// MARK: - Stub

struct StubAccessTokenProvider: AccessTokenProvider {
    func validAccessToken() async throws -> String { "" }
}
