//
//  SceneDelegate.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import SwiftUI

@MainActor
final class SceneDelegate: UIResponder, UIWindowSceneDelegate, ObservableObject {
    
    private static var systemEventsHandler: SystemEventsHandler?
    private var systemEventsHandler: SystemEventsHandler? { Self.systemEventsHandler }
    
    static func register(_ handler: SystemEventsHandler?) {
        Self.systemEventsHandler = handler
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        systemEventsHandler?.sceneDidBecomeActive()
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        systemEventsHandler?.sceneWillResignActive()
    }
}
