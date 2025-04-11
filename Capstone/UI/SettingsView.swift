//
//  SettingsView.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import SwiftUI

struct SettingsView: View {
    // This view displays user login status and settings such as About and Logout.
    @State private var isLoggedIn: Bool = true  // Replace with real auth state.
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("User Settings")
                    .font(.title)
                Text("Signed in as: user@example.com")
                
                Button(action: {
                    // Trigger logout via AuthInteractor.
                }) {
                    Text("Logout")
                        .foregroundColor(.red)
                }
                .padding()
                
                NavigationLink("About", destination: AboutView())
                NavigationLink("Acknowledgements", destination: AcknowledgementsView())
                Spacer()
            }
            .padding()
            .navigationTitle("Settings")
        }
    }
}
