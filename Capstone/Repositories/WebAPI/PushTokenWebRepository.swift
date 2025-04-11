//
//  PushTokenWebRepository.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-11.
//

import Foundation

protocol PushTokenWebRepository: WebRepository {
    func register(devicePushToken: Data) async throws
}

struct RealPushTokenWebRepository: PushTokenWebRepository {
    
    let session: URLSession
    let baseURL: String
    
    init(session: URLSession) {
        self.session = session
        self.baseURL = "https://your-server.com/api/push-token"
    }
    
    func register(devicePushToken: Data) async throws {
        // upload the push token to your server
        // you can as well call a third party library here instead
    }
}
