//
//  KeychainServiceTests.swift
//  CapstoneTests
//
//  Created by Seungwoo Choe on 2025-06-07.
//

import Testing
@testable import Capstone

@Suite("KeychainService Tests", .serialized)
struct KeychainServiceTests {
    
    private let keychain = RealKeychainService()

    @Test("Save and retrieve access token")
    func saveAndRetrieveAccessToken() throws {
        try keychain.deleteTokens()

        let testToken = "access123"
        try keychain.saveAccessToken(testToken)

        let retrieved = try #require(try keychain.getAccessToken())
        #expect(retrieved == testToken)
    }

    @Test("Access token not found returns nil")
    func accessTokenNotFound() throws {
        try keychain.deleteTokens()

        let retrieved = try keychain.getAccessToken()
        #expect(retrieved == nil)
    }

    @Test("Saving access token twice overrides previous")
    func overrideAccessToken() throws {
        try keychain.deleteTokens()

        try keychain.saveAccessToken("first")
        try keychain.saveAccessToken("second")

        let retrieved = try #require(try keychain.getAccessToken())
        #expect(retrieved == "second")
    }

    @Test("Save and retrieve refresh token")
    func saveAndRetrieveRefreshToken() throws {
        try keychain.deleteTokens()

        let testToken = "refresh123"
        try keychain.saveRefreshToken(testToken)

        let retrieved = try #require(try keychain.getRefreshToken())
        #expect(retrieved == testToken)
    }

    @Test("Refresh token not found returns nil")
    func refreshTokenNotFound() throws {
        try keychain.deleteTokens()

        let retrieved = try keychain.getRefreshToken()
        #expect(retrieved == nil)
    }

    @Test("Delete tokens removes both tokens")
    func deleteTokensRemovesBoth() throws {
        try keychain.saveAccessToken("accessToRemove")
        try keychain.saveRefreshToken("refreshToRemove")

        try keychain.deleteTokens()

        let accessAfterDelete = try keychain.getAccessToken()
        let refreshAfterDelete = try keychain.getRefreshToken()
        #expect(accessAfterDelete == nil)
        #expect(refreshAfterDelete == nil)
    }
}
