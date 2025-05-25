//
//  AboutView.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-12.
//

import SwiftUI

struct AboutView: View {
    
    @Binding var showingAbout: Bool
    @State private var showingAcknowledgements: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
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
                    
                    Spacer()
                    
                    Button("Acknowledgements") {
                        showingAcknowledgements = true
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
            }
            .defaultScrollAnchor(.center, for: .alignment)
            .padding(.top, -60)
            .toolbar {
                ToolbarItem {
                    Button("Done") {
                        showingAbout = false
                    }
                    .fontWeight(.semibold)
                }
            }
            .navigationDestination(isPresented: $showingAcknowledgements) {
                AcknowledgementsView(showingAbout: $showingAbout)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AboutView(showingAbout: .constant(true))
}
