//
//  RoomScannerView.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-04-12.
//

import SwiftUI
import ARKit
import RealityKit

// MARK: - RoomScannerView
struct RoomScannerView: View {
    // Scanning state stored directly in the view.
    @State private var captureProgress: Float = 0.0
    @State private var capturedCount: Int = 0
    
    // Store segments (each 6° wide) that have already been captured.
    @State private var capturedSegments: Set<Int> = []
    
    // Constants.
    private let totalImages: Int = 60
    private let angleThresholdDegrees: Float = 6.0  // One segment per 6° rotation.
    
    var body: some View {
        ZStack {
            // ARView container with a closure to receive yaw updates.
            ARViewContainer { currentYaw in
                processCameraAngle(currentYaw)
            }
            .ignoresSafeArea()
            
            // Overlay: scanning guide and progress indicator.
            VStack {
                Spacer()
                VStack(spacing: 8) {
                    Text("Rotate Slowly")
                        .font(.headline)
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                    
                    Text("Capturing \(capturedCount) / \(totalImages) images")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                    
                    ProgressView(value: captureProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .padding(.horizontal, 40)
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear { startSession() }
        .onDisappear { stopSession() }
    }
    
    /// Converts a yaw value (in radians) to normalized degrees [0, 360).
    private func normalizedDegrees(from yaw: Float) -> Float {
        let degrees = yaw * 180 / .pi
        return fmod(degrees + 360, 360)
    }
    
    /// Processes each AR camera update.
    private func processCameraAngle(_ currentYaw: Float) {
        // Convert the raw yaw (in radians) to a normalized angle in degrees.
        let currentAngle = normalizedDegrees(from: currentYaw)
        // Determine the segment index based on our 6° threshold.
        let segment = Int(currentAngle / angleThresholdDegrees)
        
        // Only capture a segment if it hasn't been captured before.
        if !capturedSegments.contains(segment) {
            capturedSegments.insert(segment)
            captureImage(currentAngle: currentAngle)
        }
    }
    
    /// Triggers an image capture (replace the print with your interactor call).
    private func captureImage(currentAngle: Float) {
        guard capturedCount < totalImages else { return }
        capturedCount += 1
        captureProgress = Float(capturedCount) / Float(totalImages)
        
        // Replace with your image capture interactor call.
        print("Captured image \(capturedCount) at angle: \(currentAngle)° (Segment: \(Int(currentAngle / angleThresholdDegrees)))")
        
        if capturedCount == totalImages {
            print("Capture complete with \(capturedCount) images.")
            // Initiate any post-capture processing here.
        }
    }
    
    /// Resets scanning state at the beginning of a new session.
    private func startSession() {
        capturedCount = 0
        captureProgress = 0.0
        capturedSegments = []
    }
    
    /// Cleans up any resources, if needed.
    private func stopSession() {
        // Pause or stop the AR session as required.
    }
}

// MARK: - ARViewContainer using UIViewRepresentable
struct ARViewContainer: UIViewRepresentable {
    /// Closure that passes current yaw (in radians) updates back to the view.
    let onCameraUpdate: (Float) -> Void
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        let configuration = ARWorldTrackingConfiguration()
        // For this simple scanner, no plane detection is required.
        configuration.planeDetection = []
        arView.session.run(configuration)
        
        // Set the ARSession delegate.
        arView.session.delegate = context.coordinator
        context.coordinator.arView = arView
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // No additional updates are needed.
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onCameraUpdate: onCameraUpdate)
    }
    
    /// Coordinator relays ARSession updates.
    class Coordinator: NSObject, ARSessionDelegate {
        var onCameraUpdate: (Float) -> Void
        weak var arView: ARView?
        
        // Threshold (in radians) for pitch. Here 15° ≈ 0.26 radians.
        let pitchThreshold: Float = 0.26
        
        init(onCameraUpdate: @escaping (Float) -> Void) {
            self.onCameraUpdate = onCameraUpdate
        }
        
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            let camera = frame.camera
            let eulerAngles = camera.eulerAngles
            // eulerAngles.x is the pitch. Only update if the phone is held nearly horizontally.
            if abs(eulerAngles.x) > pitchThreshold {
                return  // Ignore frames when the device is tilted up or down.
            }
            // Use the yaw from eulerAngles.y.
            let currentYaw = eulerAngles.y
            DispatchQueue.main.async {
                self.onCameraUpdate(currentYaw)
            }
        }
    }
}
