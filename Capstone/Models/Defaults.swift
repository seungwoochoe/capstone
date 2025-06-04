//
//  Defaults.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-06-04.
//

import Foundation
import Defaults
typealias Default = _Default
typealias Defaults = _Defaults

extension Defaults.Keys {
    static let userID = Key<String?>("userID")
    static let pushEndpointArn = Key<String?>("pushEndpointArn")
}
