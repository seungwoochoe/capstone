//
//  DefaultsService.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-06-04.
//

protocol DefaultsService {
    subscript<Value: Defaults.Serializable>(key: Defaults.Key<Value>) -> Value { get set }
}

struct RealDefaultsService: DefaultsService {
    subscript<Value: Defaults.Serializable>(key: Defaults.Key<Value>) -> Value {
        get { Defaults[key] }
        set { Defaults[key] = newValue }
    }
}

final class StubDefaultsService: DefaultsService {
    
    private var storage: [String: Any] = [:]
    
    subscript<Value: Defaults.Serializable>(key: Defaults.Key<Value>) -> Value {
        get {
            return (storage[key.name] as? Value) ?? key.defaultValue
        }
        set {
            storage[key.name] = newValue
        }
    }
}
