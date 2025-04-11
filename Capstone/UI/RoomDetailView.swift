//
//  RoomDetailView.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import SwiftUI
import RealityKit

struct RoomDetailView: View {
    let room: ScannedRoom
    
    var body: some View {
        VStack {
            // In a real app, you would embed an ARView or a QuickLook preview here.
            Text("3D Model View")
            Color.gray.frame(height: 300)
                .overlay(Text("USDZ Model Placeholder"))
            
            Spacer()
            
            Button(action: {
                // Implement exporting the USDZ model using the share sheet.
            }) {
                Text("Export USDZ")
            }
            .padding()
        }
        .navigationTitle(room.roomName)
    }
}
