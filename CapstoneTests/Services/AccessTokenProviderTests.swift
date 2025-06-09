//
//  AccessTokenProviderTests.swift
//  CapstoneTests
//
//  Created by Seungwoo Choe on 2025-06-07.
//

import Foundation
import Testing
@testable import Capstone

@Suite("AccessTokenProviderTests")
struct AccessTokenProviderTests {

    class FakeKeychain: KeychainService {
        var accessToken: String?
        var refreshToken: String?
        private(set) var savedAccessToken: String?
        private(set) var savedRefreshToken: String?

        func saveAccessToken(_ token: String) throws {
            savedAccessToken = token
        }
        func saveRefreshToken(_ token: String) throws {
            savedRefreshToken = token
        }
        func getAccessToken() throws -> String? {
            return accessToken
        }
        func getRefreshToken() throws -> String? {
            return refreshToken
        }
        func deleteTokens() throws {}
    }

    class FakeAuthRepo: AuthWebRepository {
        var response: AuthResponse?
        var error: Error?

        func makeHostedUISignInURL(state: String, nonce: String) -> URL {
            fatalError("Not used in these tests")
        }
        func exchange(code: String) async throws -> AuthResponse {
            fatalError("Not used in these tests")
        }
        func refreshTokens(using refreshToken: String) async throws -> AuthResponse {
            if let error = error {
                throw error
            }
            return response!
        }
    }

    @Test func returnsCachedTokenIfNotExpired() async throws {
        let keychain = FakeKeychain()
        keychain.accessToken = "cachedToken"

        let defaults = StubDefaultsService()
        defaults[.tokenExpirationDate] = Date().addingTimeInterval(60) // still valid

        let repo = FakeAuthRepo()
        let provider = RealAccessTokenProvider(
            keychainService: keychain,
            defaultsService: defaults,
            authWebRepository: repo
        )

        let token = try await provider.validAccessToken()
        #expect(token == "cachedToken")
    }

    @Test func throwsMissingAccessTokenWhenCacheValidButKeychainEmpty() async throws {
        let keychain = FakeKeychain()  // accessToken == nil
        let defaults = StubDefaultsService()
        defaults[.tokenExpirationDate] = Date().addingTimeInterval(60)

        let provider = RealAccessTokenProvider(
            keychainService: keychain,
            defaultsService: defaults,
            authWebRepository: FakeAuthRepo()
        )

        do {
            _ = try await provider.validAccessToken()
            #expect(Bool(false), "Expected .missingAccessToken when tokenExpirationDate in the future")
        } catch let error as TokenError {
            #expect(error == .missingAccessToken)
        }
    }

    @Test func throwsNoRefreshTokenWhenExpiredAndNoRefreshStored() async throws {
        let keychain = FakeKeychain()  // refreshToken == nil
        let defaults = StubDefaultsService()
        defaults[.tokenExpirationDate] = Date().addingTimeInterval(-60) // expired

        let provider = RealAccessTokenProvider(
            keychainService: keychain,
            defaultsService: defaults,
            authWebRepository: FakeAuthRepo()
        )

        do {
            _ = try await provider.validAccessToken()
            #expect(Bool(false), "Expected .noRefreshToken")
        } catch let error as TokenError {
            #expect(error == .noRefreshToken)
        }
    }

    @Test func refreshesTokenAndUpdatesKeychainAndDefaults() async throws {
        let keychain = FakeKeychain()
        keychain.refreshToken = "oldRefresh"
        let defaults = StubDefaultsService()
        let originalExpiry = Date().addingTimeInterval(-3600)
        defaults[.tokenExpirationDate] = originalExpiry

        let newAuth = AuthResponse(
            accessToken:  "brandNewAccess",
            refreshToken: "brandNewRefresh",
            expiresIn:    3600,
            userID:       nil
        )
        let repo = FakeAuthRepo()
        repo.response = newAuth

        let provider = RealAccessTokenProvider(
            keychainService: keychain,
            defaultsService: defaults,
            authWebRepository: repo
        )

        let beforeRefresh = Date()
        let token = try await provider.validAccessToken()
        #expect(token == "brandNewAccess")
        #expect(keychain.savedAccessToken == "brandNewAccess")
        #expect(keychain.savedRefreshToken == "brandNewRefresh")

        let newExpiry = defaults[.tokenExpirationDate]
        #expect(newExpiry > beforeRefresh)
        #expect(newExpiry > originalExpiry)
    }

    @Test func propagatesAuthRepositoryError() async throws {
        let keychain = FakeKeychain()
        keychain.refreshToken = "stillHere"
        let defaults = StubDefaultsService()
        defaults[.tokenExpirationDate] = Date().addingTimeInterval(-3600)

        let repo = FakeAuthRepo()
        repo.error = SampleError.oops

        let provider = RealAccessTokenProvider(
            keychainService: keychain,
            defaultsService: defaults,
            authWebRepository: repo
        )

        do {
            _ = try await provider.validAccessToken()
            #expect(Bool(false), "Expected upstream error")
        } catch {
            #expect(error as? SampleError == .oops)
        }
    }
    
    enum SampleError: Error { case oops }
}
