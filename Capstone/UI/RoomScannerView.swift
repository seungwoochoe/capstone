//
//  RoomScannerView.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-12.
//

import SwiftUI

struct RoomScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var roomName: String = ""
    // Include additional state variables for camera permissions, ARKit capture, image sampling, etc.
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Scanning Tips")
                    .font(.title2)
                Text("Ensure good lighting and move slowly for best results.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Button to start ARKit scanning (integration with ARKit/RealityKit needed)
                Button("Start Scan") {
                    // Initiate ARKit scanning session.
                    // Sample 50 images, then prompt the user to name the room,
                    // upload images and then delete temporary data upon success.
                }
                .buttonStyle(.borderedProminent)
                .padding()
                
                // Room name input field (if you want to ask for a room name prior or after scanning)
                TextField("Enter Room Name", text: $roomName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Scan Room")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
