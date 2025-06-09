//
//  RoomScannerView.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-12.
//

import SwiftUI
import RealityKit
import ARKit
import OSLog

// MARK: - RoomScannerView

struct RoomScannerView: View {
    
    @Environment(\.injected) private var injected
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var scanner = PointCloudScanner()
    @State private var isExporting: Bool = false
    @State private var exportURL: URL?
    
    @State private var isScanNamePromptPresented: Bool = false
    @State private var scanName: String = ""
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!,
                                category: String(describing: RoomScannerView.self))
    
    var body: some View {
        ZStack(alignment: .bottom) {
            
            ARViewContainer(scanner: scanner)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .fontWeight(.medium)
                    .padding(10)
                    .background(.thinMaterial, in: Capsule())
                    
                    Spacer()
                }
                .padding()
                
                Spacer()
                
                VStack(spacing: 12) {
                    if scanner.isScanning {
                        Label("Scanning…", systemImage: "dot.radiowaves.left.and.right")
                            .padding(.vertical, 8)
                            .padding(.horizontal, 20)
                            .background(Color.blue.opacity(0.75), in: Capsule())
                            .foregroundColor(.white)
                    }
                    
                    HStack(spacing: 20) {
                        // Reset
                        Button {
                            scanner.reset()
                            exportURL = nil
                            scanName = ""
                        } label: {
                            Label("Reset", systemImage: "arrow.counterclockwise")
                                .padding(.vertical, 10)
                                .padding(.horizontal, 16)
                                .background(.ultraThinMaterial, in: Capsule())
                        }
                        
                        Spacer()
                        
                        // Finish / Export
                        Button {
                            exportAndPrepareUpload()
                        } label: {
                            Label(isExporting ? "Exporting…" : "Finish Scan",
                                  systemImage: "square.and.arrow.up")
                                .padding(.vertical, 10)
                                .padding(.horizontal, 20)
                                .background(isExporting ?
                                            Color.gray.opacity(0.4) :
                                            Color.green.opacity(0.9),
                                            in: Capsule())
                                .foregroundColor(.white)
                        }
                        .disabled(isExporting)
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(colors: [.clear, .black.opacity(0.4)],
                                   startPoint: .top,
                                   endPoint: .bottom)
                        .ignoresSafeArea(edges: .bottom)
                )
            }
        }
        .alert("Name Your Scan", isPresented: $isScanNamePromptPresented) {
            TextField("Enter scan name", text: $scanName)
            Button("OK") {
                if let url = exportURL {
                    Task.detached {
                        do {
                            let uploadTask = try await injected
                                .interactors
                                .scanInteractor
                                .storeUploadTask(scanName: scanName, fileURL: url)
                            try await injected.interactors.scanInteractor.upload(uploadTask)
                        } catch {
                            logger.error("Upload failed: \(error.localizedDescription, privacy: .public)")
                        }
                    }
                }
                dismiss()
            }
            .disabled(scanName.isEmpty)
        }
    }
    
    // MARK: – Helpers
    
    private func exportAndPrepareUpload() {
        guard !isExporting else { return }
        
        isExporting = true
        scanner.exportPLY { url in
            DispatchQueue.main.async {
                self.isExporting = false
                guard let url else {
                    logger.error("Export returned nil URL")
                    return
                }
                self.exportURL = url
                self.isScanNamePromptPresented = true
            }
        }
    }
}


// MARK: – ARView Representable (LiDAR point‑cloud)

private struct ARViewContainer: UIViewRepresentable {
    
    @ObservedObject var scanner: PointCloudScanner
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // 1) Coaching overlay
        let coaching = ARCoachingOverlayView()
        coaching.session = arView.session
        coaching.goal = .tracking
        coaching.activatesAutomatically = true
        coaching.translatesAutoresizingMaskIntoConstraints = false
        arView.addSubview(coaching)
        NSLayoutConstraint.activate([
            coaching.topAnchor.constraint(equalTo: arView.topAnchor),
            coaching.bottomAnchor.constraint(equalTo: arView.bottomAnchor),
            coaching.leadingAnchor.constraint(equalTo: arView.leadingAnchor),
            coaching.trailingAnchor.constraint(equalTo: arView.trailingAnchor)
        ])
        
        // 2) Configure LiDAR + scene reconstruction
        guard ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) else {
            fatalError("Device does not support mesh reconstruction.")
        }
        
        let config = ARWorldTrackingConfiguration()
        config.sceneReconstruction = .meshWithClassification
        config.frameSemantics.insert(.sceneDepth)
        config.environmentTexturing = .automatic
        arView.session.run(config)
        
        // 3) Delegate
        arView.session.delegate = context.coordinator
        context.coordinator.arView = arView
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) { }
    
    func makeCoordinator() -> Coordinator { Coordinator(scanner: scanner) }
    
    final class Coordinator: NSObject, ARSessionDelegate {
        let scanner: PointCloudScanner
        weak var arView: ARView?
        private var latestFrame: ARFrame?
        
        init(scanner: PointCloudScanner) {
            self.scanner = scanner
            super.init()
        }
        
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            latestFrame = frame
        }
        
        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) { process(anchors) }
        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) { process(anchors) }
        
        private func process(_ anchors: [ARAnchor]) {
            guard let frame = latestFrame, let arView = arView else { return }
            for anchor in anchors.compactMap({ $0 as? ARMeshAnchor }) {
                scanner.addMeshAnchor(anchor, frame: frame, in: arView)
            }
        }
    }
}

#if DEBUG
#Preview {
    RoomScannerView()
}
#endif
