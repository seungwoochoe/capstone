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
    
    @Environment(\.injected) private var injected
    @Environment(\.dismiss) private var dismiss
    
    @State private var capturedSegments: Set<Int> = []
    @State private var currentSegment: Int? = nil
    @State private var capturedImages: [UIImage] = []
    @State private var tooFast: Bool = false
    @State private var isDeviceHorizontal: Bool = true
    @State private var isScanNamePromptPresented: Bool = false
    @State private var scanName: String = ""
    @State private var arView: ARView? = nil
    
    private let totalCaptures: Int = 60
    private let angleThresholdDegrees: Float = 6.0  // One segment per 6° rotation.
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ARViewContainer(
                onCameraUpdate: { currentYaw, tooFast, isDeviceHorizontal in
                    processCameraAngle(currentYaw, tooFast: tooFast, isDeviceHorizontal: isDeviceHorizontal)
                },
                onARViewCreated: { view in
                    DispatchQueue.main.async {
                        self.arView = view
                    }
                }
            )
            .ignoresSafeArea()
            .overlay(alignment: .topLeading) {
                if !isScanNamePromptPresented && scanName.isEmpty {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding()
                            .background(Capsule().fill(.gray.opacity(0.5)).frame(height: 40))
                    }
                    .padding()
                }
            }
            if !isScanNamePromptPresented && scanName.isEmpty {
                VStack {
                    DonutProgressView(capturedSegments: capturedSegments,
                                      totalSegments: totalCaptures,
                                      currentSegment: currentSegment)
                        .frame(width: 150, height: 150)
                        .padding(.bottom, 40)
                    
                    if !isDeviceHorizontal {
                        Text("Hold Device Horizontally")
                            .font(.headline)
                            .foregroundColor(.yellow)
                            .shadow(radius: 10)
                    } else {
                        ZStack {
                            Text("Too Fast")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.yellow)
                                .shadow(radius: 10)
                                .opacity(tooFast ? 1 : 0)
                            
                            Text("Rotate Slowly")
                                .font(.headline)
                                .foregroundColor(.white)
                                .shadow(radius: 10)
                                .opacity(tooFast ? 0 : 1)
                        }
                    }
                }
            }
        }
        .onAppear { startSession() }
        .onDisappear { stopSession() }
        .alert("Name Your Scan", isPresented: $isScanNamePromptPresented) {
            TextField("Enter scan name", text: $scanName)
            Button("OK") {
                Task {
                    let uploadTaskDTO = try await injected.interactors.scanInteractor.storeUploadTask(scanName: scanName, images: capturedImages)
                    try await injected.interactors.scanInteractor.upload(uploadTaskDTO: uploadTaskDTO)
                }
                dismiss()
            }
            .disabled(scanName.isEmpty)
        }
    }
    
    private func normalizedDegrees(from yaw: Float) -> Float {
        let degrees = yaw * 180 / .pi
        return fmod(degrees + 360, 360)
    }
    
    private func processCameraAngle(_ currentYaw: Float, tooFast: Bool, isDeviceHorizontal: Bool) {
        self.isDeviceHorizontal = isDeviceHorizontal
        // Only process capturing if the device is held horizontally.
        guard isDeviceHorizontal else { return }
        
        if self.tooFast && !tooFast {
            withAnimation(.linear(duration: 1.5).delay(1.5)) {
                self.tooFast = tooFast
            }
        } else {
            self.tooFast = tooFast
        }
        
        let normalizedAngle = normalizedDegrees(from: currentYaw)
        // Compute the scanning angle relative to the donut.
        let scanningAngle = fmod(90 + normalizedAngle + 360, 360)
        // Offset by half the segment angle to center the segment thresholds.
        let adjustedAngle = fmod(scanningAngle + angleThresholdDegrees / 2, 360)
        let segment = Int(adjustedAngle / angleThresholdDegrees)
        self.currentSegment = segment
        
        guard !tooFast else { return }
        
        if !capturedSegments.contains(segment) {
            capturedSegments.insert(segment)
            captureImage(currentAngle: scanningAngle)
        }
    }
    
    private func captureImage(currentAngle: Float) {
        guard capturedImages.count < totalCaptures else { return }
        
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
                    print("Captured image \(self.capturedImages.count) at angle: \(currentAngle)°")
                    if self.capturedImages.count == self.totalCaptures {
                        print("Capture complete with \(self.capturedImages.count) images.")
                        self.arView?.session.pause()
                        self.isScanNamePromptPresented = true
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
        capturedSegments = []
        capturedImages = []
        scanName = ""
        isScanNamePromptPresented = false
    }
    
    private func stopSession() {
        // Implement any needed AR session cleanup here.
    }
}

// MARK: - ARViewContainer

struct ARViewContainer: UIViewRepresentable {
    
    let onCameraUpdate: (Float, Bool, Bool) -> Void
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
        var onCameraUpdate: (Float, Bool, Bool) -> Void
        weak var arView: ARView?
        
        private let pitchThreshold: Float = 0.26 // (15° ≈ 0.26 radians)
        private let angularVelocityThreshold: Float = 30.0
        
        // Variables to track the last yaw and timestamp for computing angular velocity.
        var lastYaw: Float?
        var lastTimestamp: TimeInterval?
        
        init(onCameraUpdate: @escaping (Float, Bool, Bool) -> Void) {
            self.onCameraUpdate = onCameraUpdate
        }
        
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            let camera = frame.camera
            let eulerAngles = camera.eulerAngles
            
            // Determine if the device is held horizontally (i.e. pitch near 0).
            let isDeviceHorizontal = abs(eulerAngles.x) <= pitchThreshold
            
            var tooFast = false
            if isDeviceHorizontal {
                if let lastYaw = lastYaw, let lastTimestamp = lastTimestamp, frame.timestamp > lastTimestamp {
                    let deltaTime = frame.timestamp - lastTimestamp
                    let deltaYaw = abs(eulerAngles.y - lastYaw)
                    let angularVelocityDegrees = (deltaYaw * 180 / .pi) / Float(deltaTime)
                    tooFast = angularVelocityDegrees > angularVelocityThreshold
                }
                lastYaw = eulerAngles.y
                lastTimestamp = frame.timestamp
            }
            
            DispatchQueue.main.async {
                self.onCameraUpdate(eulerAngles.y, tooFast, isDeviceHorizontal)
            }
        }
    }
}

// MARK: - DonutProgressView

struct DonutProgressView: UIViewRepresentable {
    
    let capturedSegments: Set<Int>
    let totalSegments: Int
    let currentSegment: Int?

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = .clear
        
        let scene = SCNScene()
        scnView.scene = scene
        
        // Build and add the donut node.
        let donut = context.coordinator.makeDonutNode(totalSegments: totalSegments)
        scene.rootNode.addChildNode(donut)
        
        // Set up a simple camera.
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 0, 2)
        scene.rootNode.addChildNode(cameraNode)
        
        scnView.autoenablesDefaultLighting = true
        
        return scnView
    }
    
    func updateUIView(_ scnView: SCNView, context: Context) {
        guard let donut = scnView.scene?.rootNode.childNode(withName: "donut", recursively: false) else { return }
        
        for i in 0..<totalSegments {
            if let segmentNode = donut.childNode(withName: "segment\(i)", recursively: false),
               let material = segmentNode.geometry?.firstMaterial {
                
                // Determine the base color based on whether the segment is captured.
                let baseColor = capturedSegments.contains(i) ? UIColor.systemGreen : UIColor.lightGray
                
                // If this segment is currently being scanned, override it with a brighter highlight.
                if let current = currentSegment, current == i {
                    let highlightColor = capturedSegments.contains(i) ?
                        UIColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0) :
                        UIColor(white: 0.8, alpha: 1.0)
                    material.diffuse.contents = highlightColor
                } else {
                    material.diffuse.contents = baseColor
                }
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
            
            let innerRadius: CGFloat = 0.5
            let outerRadius: CGFloat = 0.8
            let extrusionDepth: CGFloat = 0.05
            let anglePerSegment = (2 * CGFloat.pi) / CGFloat(totalSegments)
            
            for i in 0..<totalSegments {
                let startAngle = anglePerSegment * CGFloat(i)
                let endAngle = startAngle + anglePerSegment
                
                let path = UIBezierPath()
                path.move(to: CGPoint(x: innerRadius * cos(startAngle), y: innerRadius * sin(startAngle)))
                path.addArc(withCenter: .zero,
                            radius: innerRadius,
                            startAngle: startAngle,
                            endAngle: endAngle,
                            clockwise: true)
                path.addLine(to: CGPoint(x: outerRadius * cos(endAngle), y: outerRadius * sin(endAngle)))
                path.addArc(withCenter: .zero,
                            radius: outerRadius,
                            startAngle: endAngle,
                            endAngle: startAngle,
                            clockwise: false)
                path.close()
                
                let shape = SCNShape(path: path, extrusionDepth: extrusionDepth)
                shape.chamferRadius = 0.005
                shape.chamferMode = .both
                
                let material = SCNMaterial()
                material.diffuse.contents = UIColor.lightGray
                shape.materials = [material]
                
                let segmentNode = SCNNode(geometry: shape)
                segmentNode.name = "segment\(i)"
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
