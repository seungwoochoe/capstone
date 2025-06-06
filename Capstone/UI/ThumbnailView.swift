//
//  ThumbnailView.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-05-06.
//

import SwiftUI
import SceneKit
import OSLog

struct USDZThumbnailView: View {
    let url: URL
    let size: CGSize
    @State private var thumbnail: UIImage?
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: #file)
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
            if let img = thumbnail {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: size.width, height: size.height)
        .cornerRadius(8)
        .onAppear {
            Task.detached(priority: .userInitiated) {
                await generateThumbnail()
            }
        }
    }
    
    private func generateThumbnail() async {
        do {
            let scene = try SCNScene(url: url, options: nil)
            let (center, radius) = scene.rootNode.boundingSphere
            
            // Ambient lighting
            let ambientLight = SCNLight()
            ambientLight.type = .ambient
            ambientLight.intensity = 300
            let ambientNode = SCNNode()
            ambientNode.light = ambientLight
            scene.rootNode.addChildNode(ambientNode)
            
            // Key lighting
            let keyLight = SCNLight()
            keyLight.type = .directional
            keyLight.intensity = 1000
            let keyNode = SCNNode()
            keyNode.light = keyLight
            keyNode.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 4, 0)
            scene.rootNode.addChildNode(keyNode)
            
            // Metal renderer setup
            guard let device = MTLCreateSystemDefaultDevice() else {
                logger.error("Metal unavailable")
                return
            }
            let renderer = SCNRenderer(device: device, options: nil)
            renderer.scene = scene
            
            // Camera configuration
            let camNode: SCNNode
            if let existingCam = scene.rootNode.childNode(withName: "camera", recursively: true) {
                camNode = existingCam
            } else {
                let cam = SCNCamera()
                cam.fieldOfView = 60
                camNode = SCNNode()
                camNode.name = "camera"
                camNode.camera = cam
                scene.rootNode.addChildNode(camNode)
            }
            
            let distance = radius * 1.2
            let elevation = radius * 0.5
            camNode.position = SCNVector3(
                center.x,
                center.y + Float(elevation),
                center.z + Float(distance)
            )
            camNode.look(at: center)
            renderer.pointOfView = camNode
            
            let scale = UIScreen.main.scale
            let renderSize = CGSize(width: size.width * scale,
                                    height: size.height * scale)
            
            let rawImage = renderer.snapshot(atTime: 0,
                                             with: renderSize,
                                             antialiasingMode: .multisampling4X)
            
            guard let cg = rawImage.cgImage else {
                logger.error("Failed to extract CGImage from snapshot")
                return
            }
            let image = UIImage(cgImage: cg,
                                scale: scale,
                                orientation: .up)
            
            await MainActor.run {
                self.thumbnail = image
            }
        } catch {
            logger.error("Failed to load USDZ: \(error.localizedDescription)")
        }
    }
}

#Preview {
    USDZThumbnailView(url: Scan.sample.usdzURL, size: CGSize(width: 50, height: 50))
}
