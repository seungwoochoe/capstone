//
//  RootView.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-06-04.
//

import SwiftUI
import Combine

struct RootView: View {
    
    @Environment(\.injected) private var injected
    @State private var isSignedIn: Bool = false
    @State private var didSyncInitialValue: Bool = false

    var body: some View {
        Group {
            if isSignedIn {
                ContentView()
            } else {
                SignInView()
            }
        }
        .onReceive(isSignedInUpdate) { newValue in
            if didSyncInitialValue {
                withAnimation {
                    isSignedIn = newValue
                }
            } else {
                isSignedIn = newValue
                didSyncInitialValue = true
            }
        }
    }
    
    private var isSignedInUpdate: AnyPublisher<Bool, Never> {
        injected.appState.updates(for: \.auth.isSignedIn)
    }
}
