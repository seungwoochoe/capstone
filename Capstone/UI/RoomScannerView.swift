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
    @State private var capturedImages: [UIImage] = []
    @State private var isRoomNamePromptPresented: Bool = false
    @State private var roomName: String = ""
    
    // Store a reference to the active ARView.
    @State private var arView: ARView? = nil
    
    private let totalCaptures: Int = 60
    private let angleThresholdDegrees: Float = 6.0  // One segment per 6° rotation.
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ARViewContainer(
                onCameraUpdate: { currentYaw in
                    processCameraAngle(currentYaw)
                },
                onARViewCreated: { view in
                    DispatchQueue.main.async {
                        self.arView = view
                    }
                }
            )
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
        // Overlay a custom prompt when all captures are complete.
        .overlay {
            if isRoomNamePromptPresented {
                RoomNamePrompt(roomName: $roomName) { name in
                    // When the user taps OK, print the room name.
                    print("Room name: \(name)")
                    // Continue with upload/processing logic, then dismiss the prompt.
                    isRoomNamePromptPresented = false
                }
            }
        }
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
        
        guard let arView = arView else {
            print("ARView not ready for snapshot. Retrying...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                captureImage(currentAngle: currentAngle)
            }
            return
        }
        
        arView.snapshot(saveToHDR: false) { image in
            if let image = image {
                DispatchQueue.main.async {
                    self.capturedImages.append(image)
                    print("Captured image \(self.capturedCount) at angle: \(currentAngle)°")
                    if self.capturedCount == self.totalCaptures {
                        print("Capture complete with \(self.capturedCount) images.")
                        // Pause the AR session to stop the delegate from holding ARFrames.
                        self.arView?.session.pause()
                        self.isRoomNamePromptPresented = true
                    }
                }
            } else {
                print("Snapshot failed. Retrying...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    captureImage(currentAngle: currentAngle)
                }
            }
        }
    }
    
    private func startSession() {
        // Is this needed?
        capturedCount = 0
        capturedSegments = []
        capturedImages = []
        roomName = ""
        isRoomNamePromptPresented = false
    }
    
    private func stopSession() {
        // Implement any needed AR session cleanup.
    }
}

// MARK: - Room Name Prompt

struct RoomNamePrompt: View {
    @Binding var roomName: String
    var onComplete: (String) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Name Your Scan")
                .font(.headline)
            TextField("Enter room name", text: $roomName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            Button("OK") {
                onComplete(roomName)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .padding()
    }
}

// MARK: - ARViewContainer

struct ARViewContainer: UIViewRepresentable {
    
    // Closure that passes current yaw (in radians) updates back to RoomScannerView.
    let onCameraUpdate: (Float) -> Void
    // New closure to pass the created ARView back.
    let onARViewCreated: (ARView) -> Void
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        let configuration = ARWorldTrackingConfiguration()
        
        // For this scanner, no plane detection is required.
        configuration.planeDetection = []
        arView.session.run(configuration)
        
        // Set the ARSession delegate.
        arView.session.delegate = context.coordinator
        context.coordinator.arView = arView
        
        // Pass the created ARView back to the parent view.
        onARViewCreated(arView)
        
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
        // Weak reference to avoid retain cycles.
        weak var arView: ARView?
        
        // Define a pitch threshold (15° ≈ 0.26 radians) to ignore frames when the device is tilted too much.
        private static let pitchThreshold: Float = 0.26
        
        init(onCameraUpdate: @escaping (Float) -> Void) {
            self.onCameraUpdate = onCameraUpdate
        }
        
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            let camera = frame.camera
            let eulerAngles = camera.eulerAngles
            
            // Only update if the device is held nearly horizontally.
            if abs(eulerAngles.x) > Coordinator.pitchThreshold {
                return
            }
            
            // Use the yaw (eulerAngles.y) for the scanning.
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
        
        // Build and add the donut node.
        let donut = context.coordinator.makeDonutNode(totalSegments: totalSegments)
        scene.rootNode.addChildNode(donut)
        
        // Set up a simple camera.
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        // Position the camera so it looks at the donut.
        cameraNode.position = SCNVector3(0, 0, 2)
        scene.rootNode.addChildNode(cameraNode)
        
        // Enable default lighting.
        scnView.autoenablesDefaultLighting = true
        
        return scnView
    }
    
    func updateUIView(_ scnView: SCNView, context: Context) {
        // Update each segment’s material based on the capture progress.
        guard let donut = scnView.scene?.rootNode.childNode(withName: "donut", recursively: false) else { return }
        
        for i in 0..<totalSegments {
            if let segmentNode = donut.childNode(withName: "segment\(i)", recursively: false),
               let material = segmentNode.geometry?.firstMaterial {
                // Use green if the segment is captured, otherwise light gray.
                material.diffuse.contents = capturedSegments.contains(i) ? UIColor.systemGreen : UIColor.lightGray
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        
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
                // Draw the outer arc (in reverse) to close the shape.
                path.addArc(withCenter: .zero,
                            radius: outerRadius,
                            startAngle: endAngle,
                            endAngle: startAngle,
                            clockwise: false)
                // Close the path.
                path.close()
                
                // Create a shape from the path with the desired extrusion depth.
                let shape = SCNShape(path: path, extrusionDepth: extrusionDepth)
                shape.chamferRadius = 0.005  // Smooth the edges.
                shape.chamferMode = .both
                
                // Create a material (default light gray).
                let material = SCNMaterial()
                material.diffuse.contents = UIColor.lightGray
                shape.materials = [material]
                
                // Create the node for this segment.
                let segmentNode = SCNNode(geometry: shape)
                segmentNode.name = "segment\(i)"
                // Rotate so that the flat face is horizontal.
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
