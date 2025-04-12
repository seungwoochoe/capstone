//
//  Model3DViewer.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-12.
//

import SwiftUI
import RealityKit

struct Model3DViewer: View {
    
    let scan: Scan
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                // ARViewContainer displays the 3D model using RealityKit
//                ARViewContainer(usdzURL: scan.usdzURL)
//                    .ignoresSafeArea()
//                
                // Overlay controls for export and deletion
                VStack {
                    Spacer()
                    HStack(spacing: 20) {
                        Button {
                            exportModel()
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.up")
                                .padding()
                                .background(Capsule().fill(Color.blue.opacity(0.8)))
                                .foregroundColor(.white)
                        }
                        
                        Button {
                            deleteScan(scan)
                            dismiss()
                        } label: {
                            Label("Delete", systemImage: "trash")
                                .padding()
                                .background(Capsule().fill(Color.red.opacity(0.8)))
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(scan.name)
        }
    }
    
    // MARK: - Export and Delete Handlers
    
    private func exportModel() {
        // Use UIActivityViewController to share the USDZ file.
        // (Implement the actual export logic based on your needs.)
    }
    
    private func deleteScan(_ scan: Scan) {
        // Delete the scan from local storage.
        // (Integrate SwiftData deletion here.)
    }
}
