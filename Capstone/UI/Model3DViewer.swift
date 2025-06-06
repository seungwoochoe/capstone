//
//  Model3DViewer.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-12.
//

import SwiftUI
import SceneKit
import OSLog

struct Model3DViewer: View {
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.injected) private var injected
    
    let scan: Scan
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: #file)
    
    var body: some View {
        NavigationStack {
            ZStack {
                USDZModelView(modelURL: scan.usdzURL)
                    .ignoresSafeArea()
                
                VStack {
                    Spacer()
                    HStack(spacing: 60) {
                        ShareLink(item: scan.usdzURL) {
                            Label("Export", systemImage: "square.and.arrow.up")
                                .padding()
                                .background(Capsule().fill(Color.blue.opacity(0.9)))
                                .foregroundColor(.white)
                        }
                        
                        Button {
                            delete(scan)
                        } label: {
                            Label("Delete", systemImage: "trash")
                                .padding()
                                .background(Capsule().fill(Color.red.opacity(0.9)))
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(scan.name)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func delete(_ scan: Scan) {
        Task {
            do {
                try await injected.interactors.scanInteractor.delete(scan)
                dismiss()
            } catch {
                logger.debug("Error deleting scan: \(error)")
            }
        }
    }
}

private struct USDZModelView: UIViewRepresentable {
    
    let modelURL: URL
    
    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        if let scene = try? SCNScene(url: modelURL) {
            sceneView.scene = scene
        }
        
        sceneView.allowsCameraControl = true
        sceneView.autoenablesDefaultLighting = true
        sceneView.backgroundColor = .white
        return sceneView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        // No dynamic updates
    }
}

#Preview {
    Model3DViewer(scan: Scan.sample)
}
