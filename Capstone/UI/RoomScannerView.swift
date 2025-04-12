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
                    .padding(.bottom, 40)
                
                Text("Rotate Slowly")
                    .font(.headline)
                    .foregroundColor(.white)
                    .shadow(radius: 10)
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
        let normalizedAngle = normalizedDegrees(from: currentYaw)
        
        // Compute the scanning angle relative to the donut.
        let scanningAngle = fmod(90 + normalizedAngle + 360, 360)
        
        // Offset by half the segment angle to center the segment thresholds.
        // This ensures that values near 360° and 0° (i.e., when wrapping around)
        // are considered part of the same segment.
        let adjustedAngle = fmod(scanningAngle + angleThresholdDegrees / 2, 360)
        let segment = Int(adjustedAngle / angleThresholdDegrees)
        
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
    
    // Threshold (in radians) for pitch. Here 15° ≈ 0.26 radians.
    private static let pitchThreshold: Float = 0.26
    
    // Closure that passes current yaw (in radians) updates back to the view.
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
        
        init(onCameraUpdate: @escaping (Float) -> Void) {
            self.onCameraUpdate = onCameraUpdate
        }
        
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            let camera = frame.camera
            let eulerAngles = camera.eulerAngles
            
            // eulerAngles.x is the pitch. Only update if the phone is held nearly horizontally.
            if abs(eulerAngles.x) > pitchThreshold {
                return  // Ignore frames when the device is tilted up or down too much.
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

        // Creates the donut node composed of smooth, curved segments.
        func makeDonutNode(totalSegments: Int) -> SCNNode {
            let donutNode = SCNNode()
            donutNode.name = "donut"
            // Tilt the whole donut.
            donutNode.eulerAngles.x = +Float.pi / 6
            
            // Define radii and extrusion depth.
            let innerRadius: CGFloat = 0.5
            let outerRadius: CGFloat = 0.8
            let extrusionDepth: CGFloat = 0.05
            let anglePerSegment = (2 * CGFloat.pi) / CGFloat(totalSegments)
            
            for i in 0..<totalSegments {
                let startAngle = anglePerSegment * CGFloat(i)
                let endAngle = startAngle + anglePerSegment
                
                // Create a path for the donut segment.
                let path = UIBezierPath()
                // Start at the inner circle at the start angle.
                path.move(to: CGPoint(x: innerRadius * cos(startAngle), y: innerRadius * sin(startAngle)))
                // Draw the inner arc.
                path.addArc(withCenter: .zero,
                            radius: innerRadius,
                            startAngle: startAngle,
                            endAngle: endAngle,
                            clockwise: true)
                // Draw a line connecting to the outer circle.
                path.addLine(to: CGPoint(x: outerRadius * cos(endAngle), y: outerRadius * sin(endAngle)))
                // Draw the outer arc (going in the reverse direction to close the shape).
                path.addArc(withCenter: .zero,
                            radius: outerRadius,
                            startAngle: endAngle,
                            endAngle: startAngle,
                            clockwise: false)
                // Close the path.
                path.close()
                
                // Create a shape from the path with the desired extrusion depth.
                let shape = SCNShape(path: path, extrusionDepth: extrusionDepth)
                
                // Set a small chamfer to further smooth the edges.
                shape.chamferRadius = 0.005
                shape.chamferMode = .both
                
                // Create a material (light gray by default).
                let material = SCNMaterial()
                material.diffuse.contents = UIColor.lightGray
                shape.materials = [material]
                
                // Create a node for the segment.
                let segmentNode = SCNNode(geometry: shape)
                segmentNode.name = "segment\(i)"
                
                // Rotate the segment so that its flat face is horizontal.
                segmentNode.eulerAngles.x = -Float.pi / 2
                
                donutNode.addChildNode(segmentNode)
            }
            
            return donutNode
        }
    }
}

#Preview {
    RoomScannerView()
}
