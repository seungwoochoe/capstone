//
//  AboutView.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-12.
//

import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Capstone App")
                    .font(.title)
                Text("Version 1.0.0")
                Text("Acknowledgments: Thanks to the team and open-source libraries.")
                Spacer()
            }
            .padding()
            .navigationTitle("About")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
