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
    @State private var capturedCount: Int = 0
    @State private var capturedSegments: Set<Int> = []
    
    private let totalCaptures: Int = 60
    private let angleThresholdDegrees: Float = 6.0  // One segment per 6° rotation.
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ARViewContainer { currentYaw in
                processCameraAngle(currentYaw)
            }
            .ignoresSafeArea()
            
            VStack {
                DonutProgressView(capturedSegments: capturedSegments, totalSegments: totalCaptures)
                    .frame(width: 150, height: 150)
                    .padding(.bottom, 50)
                
                Text("Rotate Slowly")
                    .font(.headline)
                    .foregroundColor(.white)
                    .shadow(radius: 2)
            }
        }
        .onAppear { startSession() }
        .onDisappear { stopSession() }
    }
    
    private func normalizedDegrees(from yaw: Float) -> Float {
        let degrees = yaw * 180 / .pi
        return fmod(degrees + 360, 360)
    }
    
    private func processCameraAngle(_ currentYaw: Float) {
        // Convert yaw (in radians) to normalized degrees [0, 360)
        let normalizedAngle = normalizedDegrees(from: currentYaw)
        
        // Compute the scanning angle relative to the donut.
        // The donut’s furthest point (backside) is at 270°.
        // By computing (270 - normalizedAngle + 360) mod 360,
        // we ensure that when normalizedAngle == 270°, scanningAngle becomes 0°.
        // Also, as you rotate clockwise (reducing normalizedAngle),
        // the scanningAngle increases, marking segments in clockwise order.
        let scanningAngle = fmod(270 - normalizedAngle + 360, 360)
        
        // Determine which segment should be captured.
        let segment = Int(scanningAngle / angleThresholdDegrees)
        
        if !capturedSegments.contains(segment) {
            capturedSegments.insert(segment)
            captureImage(currentAngle: scanningAngle)
        }
    }
    
    private func captureImage(currentAngle: Float) {
        guard capturedCount < totalCaptures else { return }
        capturedCount += 1
        
        print("Captured image \(capturedCount) at angle: \(currentAngle)° (Segment: \(Int(currentAngle / angleThresholdDegrees)))")
        
        if capturedCount == totalCaptures {
            print("Capture complete with \(capturedCount) images.")
        }
    }
    
    private func startSession() {
        capturedCount = 0
        capturedSegments = []
    }
    
    private func stopSession() {
        // Stop your AR session if needed.
    }
}

// MARK: - ARViewContainer

struct ARViewContainer: UIViewRepresentable {
    
    /// Closure that passes current yaw (in radians) updates back to the view.
    let onCameraUpdate: (Float) -> Void
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        let configuration = ARWorldTrackingConfiguration()
        
        // For this scanner, no plane detection is required.
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

// MARK: - DonutProgressView

struct DonutProgressView: UIViewRepresentable {
    
    let capturedSegments: Set<Int>
    let totalSegments: Int

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = .clear

        // Create an empty scene.
        let scene = SCNScene()
        scnView.scene = scene
        
        // Build and add the doughnut node.
        let donut = context.coordinator.makeDonutNode(totalSegments: totalSegments)
        scene.rootNode.addChildNode(donut)
        
        // Set up a simple camera.
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        // Position the camera so it looks at the donut.
        cameraNode.position = SCNVector3(0, 0, 2)
        scene.rootNode.addChildNode(cameraNode)
        
        // Default lighting.
        scnView.autoenablesDefaultLighting = true
        
        return scnView
    }

    func updateUIView(_ scnView: SCNView, context: Context) {
        // Update each segment’s material based on capture progress.
        guard let donut = scnView.scene?.rootNode.childNode(withName: "donut", recursively: false) else { return }
        
        for i in 0..<totalSegments {
            if let segmentNode = donut.childNode(withName: "segment\(i)", recursively: false),
               let material = segmentNode.geometry?.firstMaterial {
                // Use green if captured, otherwise light gray.
                material.diffuse.contents = capturedSegments.contains(i) ? UIColor.systemGreen : UIColor.lightGray
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }

    class Coordinator: NSObject {
        
        // Creates the donut node composed of individual segments.
        func makeDonutNode(totalSegments: Int) -> SCNNode {
            let donutNode = SCNNode()
            donutNode.name = "donut"
            
            // Rotate the donut to tilt it on its X-axis.
            donutNode.eulerAngles.x = +Float.pi / 6
            
            // Define the ring’s geometry.
            let innerRadius: CGFloat = 0.2
            let outerRadius: CGFloat = 0.8
            let thickness: CGFloat = outerRadius - innerRadius
            let midRadius: CGFloat = (innerRadius + outerRadius) / 2

            // Calculate the angle per segment.
            let anglePerSegment = (2 * CGFloat.pi) / CGFloat(totalSegments)
            
            // Create segments as small boxes.
            for i in 0..<totalSegments {
                // Compute approximate arc length.
                let chord = 2 * midRadius * sin(anglePerSegment / 2)
                let box = SCNBox(width: chord, height: 0.05, length: thickness, chamferRadius: 0.005)
                
                // Default color for un-captured segments.
                let material = SCNMaterial()
                material.diffuse.contents = UIColor.lightGray
                box.materials = [material]
                
                let segmentNode = SCNNode(geometry: box)
                segmentNode.name = "segment\(i)"
                
                // Calculate position along a circle.
                let angle = anglePerSegment * CGFloat(i)
                let x = midRadius * cos(angle)
                let z = midRadius * sin(angle)
                segmentNode.position = SCNVector3(x, 0, z)
                
                // Rotate segment so that its longer axis lies tangentially.
                segmentNode.eulerAngles = SCNVector3(0, -Float(angle), 0)
                
                donutNode.addChildNode(segmentNode)
            }
            
            return donutNode
        }
    }
}

#Preview {
    RoomScannerView()
}
