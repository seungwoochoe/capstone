//
//  App.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-03-30.
//

import SwiftUI

@main
struct CapstoneApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            appDelegate.rootView
        }
    }
}

extension AppEnvironment {
    var rootView: some View {
        VStack {
            if isRunningTests {
                Text("Running unit tests")
            } else {
                Group {
                    if let token = try? keychainService.getToken() {
                        ContentView()
                            .modifier(RootViewAppearance())
                            .modelContainer(modelContainer)
                            .inject(diContainer)
                        if modelContainer.isStub {
                            Text("⚠️ There is an issue with local database")
                        }
                    } else {
                        // No token found → show SignInView first.
                        SignInView()
                            .modifier(RootViewAppearance())
                            .modelContainer(modelContainer)
                            .inject(diContainer)
                    }
                }
            }
        }
    }
}
