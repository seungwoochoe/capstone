//
//  ScanRoomView.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-09.
//

import SwiftUI

struct ScanRoomView: View {
    // This view displays scanning tips and a button to start a new scan.
    @State private var roomName: String = ""
    @State private var isScanning: Bool = false

    var body: some View {
        VStack {
            if isScanning {
                Text("Scanning... Follow the tips for good quality.")
                // Here you would embed your ARView integrated with ARKit/RealityKit.
            } else {
                Text("Ready to Scan Your Room")
            }
            
            Button(action: {
                // Start your ARKit scanning process.
                isScanning = true
                // Once done, prompt for room name and trigger the upload process.
            }) {
                Text("Start Scan")
                    .font(.title)
                    .padding()
            }
            
            if isScanning {
                TextField("Enter room name", text: $roomName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
            }
        }
        .padding()
    }
}
