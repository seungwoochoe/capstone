//
//  SettingsView.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-12.
//

import SwiftUI

struct SettingsView: View {
    
    @Binding var showingSettings: Bool
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button("Log Out", role: .destructive) {
                        
                    }
                } header: {
                    HStack {
                        Spacer()
                        VStack(spacing: 30) {
                            Image(systemName: "app.fill")
                                .resizable()
                                .foregroundStyle(.gray)
                                .frame(width: 100, height: 100)
                                .cornerRadius(20)
                            
                            Text("3D Room Scanner")
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text("Version \(SCApp.version)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .textCase(.none)
                    .padding()
                    .padding(.bottom)
                }
                
                Section {
                    NavigationLink("Acknowledgements") {
                        AcknowledgementsView(showingSettings: $showingSettings)
                    }
                }
            }
            .toolbar {
                ToolbarItem {
                    Button("Done") {
                        showingSettings = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView(showingSettings: .constant(true))
}
