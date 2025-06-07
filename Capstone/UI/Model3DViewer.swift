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
                USDZModelView(modelURL: scan.usdzURL(fileManager: injected.services.fileManager))
                    .ignoresSafeArea()
                
                VStack {
                    Spacer()
                    HStack(spacing: 60) {
                        ShareLink(item: scan.usdzURL(fileManager: injected.services.fileManager)) {
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
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "USDZModelView")
    
    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        
        do {
            let scene = try SCNScene(url: modelURL, options: nil)
            sceneView.scene = scene
        } catch {
            logger.error("Failed to load USDZ: \(error.localizedDescription)")
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

private struct PLYModelView: UIViewRepresentable {
    
    let plyURL: URL
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "PLYModelView")
    
    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.allowsCameraControl      = true
        scnView.autoenablesDefaultLighting = true
        scnView.backgroundColor          = .white
        
        do {
            let geometry = try PLYParser.geometry(from: plyURL)
            let scene    = SCNScene()
            
            let node     = SCNNode(geometry: geometry)
            scene.rootNode.addChildNode(node)
            
            // Centre the point cloud around the origin so initial camera framing looks good.
            let (min, max) = node.boundingBox
            let center     = SCNVector3((min.x + max.x) * 0.5,
                                        (min.y + max.y) * 0.5,
                                        (min.z + max.z) * 0.5)
            node.position  = SCNVector3(-center.x, -center.y, -center.z)
            
            scnView.scene = scene
        } catch {
            logger.error("Could not load PLY file: \(error.localizedDescription)")
        }
        return scnView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) { /* no-op */ }
}

private enum PLYParser {
    
    /// Returns an `SCNGeometry` whose primitive type is `.point` and
    /// whose geometry sources provide per-vertex colour.
    static func geometry(from url: URL) throws -> SCNGeometry {
        let file = try String(contentsOf: url, encoding: .utf8)
        let lines = file.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        // -------- Header --------
        guard lines.first == "ply" else { throw NSError(domain: "PLY", code: 0,
                                                        userInfo: [NSLocalizedDescriptionKey: "Not a PLY file"]) }
        guard let formatLine = lines.dropFirst().first,
              formatLine.hasPrefix("format ascii") else {
            throw NSError(domain: "PLY", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Only ASCII PLY is supported"])
        }
        
        // Read number of vertices & property order.
        var vertexCount = 0
        var propertyOrder: [String] = []
        var i = 0
        while i < lines.count {
            let l = lines[i]
            if l.hasPrefix("element vertex") {
                vertexCount = Int(l.split(separator: " ")[2]) ?? 0
            } else if l.hasPrefix("property") {
                // property float x  |  property uchar red ...
                if let name = l.split(separator: " ").last { propertyOrder.append(String(name)) }
            } else if l == "end_header" {
                i += 1; break
            }
            i += 1
        }
        guard vertexCount > 0 else { throw NSError(domain: "PLY", code: 2,
                                                   userInfo: [NSLocalizedDescriptionKey: "No vertex element in header"]) }
        
        // Positions & colours in header order
        guard let xIdx = propertyOrder.firstIndex(of: "x"),
              let yIdx = propertyOrder.firstIndex(of: "y"),
              let zIdx = propertyOrder.firstIndex(of: "z") else {
            throw NSError(domain: "PLY", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "x/y/z properties not found"])
        }
        guard let rIdx = propertyOrder.firstIndex(of: "red"),
              let gIdx = propertyOrder.firstIndex(of: "green"),
              let bIdx = propertyOrder.firstIndex(of: "blue") else {
            throw NSError(domain: "PLY", code: 4,
                          userInfo: [NSLocalizedDescriptionKey: "r/g/b properties not found"])
        }
        
        // -------- Body --------
        var positions = [Float32]()
        var colours   = [Float32]()
        positions.reserveCapacity(vertexCount * 3)
        colours.reserveCapacity(vertexCount * 3)
        
        let bodyLines = lines[i ..< min(i + vertexCount, lines.count)]
        for line in bodyLines {
            let comps = line.split(whereSeparator: \.isWhitespace)
            guard comps.count >= propertyOrder.count else { continue }
            
            let x = Float32(comps[xIdx]) ?? 0
            let y = Float32(comps[yIdx]) ?? 0
            let z = Float32(comps[zIdx]) ?? 0
            let r = Float32(comps[rIdx]) ?? 0
            let g = Float32(comps[gIdx]) ?? 0
            let b = Float32(comps[bIdx]) ?? 0
            
            positions.append(contentsOf: [x, y, z])
            colours.append(contentsOf: [r / 255.0, g / 255.0, b / 255.0])
        }
        
        // ---- Geometry sources ----
        let posData = positions.withUnsafeBufferPointer { Data(buffer: $0) }
        let colData = colours .withUnsafeBufferPointer { Data(buffer: $0) }

        let posSource = SCNGeometrySource(
            data: posData,
            semantic: .vertex,
            vectorCount: vertexCount,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float32>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<Float32>.size * 3
        )

        let colSource = SCNGeometrySource(
            data: colData,
            semantic: .color,
            vectorCount: vertexCount,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float32>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<Float32>.size * 3
        )

        // ---- Geometry element (indices) ----
        let indices = (0..<vertexCount).map { UInt32($0) }
        let idxData = indices.withUnsafeBufferPointer { Data(buffer: $0) }

        let element = SCNGeometryElement(
            data: idxData,
            primitiveType: .point,
            primitiveCount: vertexCount,
            bytesPerIndex: MemoryLayout<UInt32>.size
        )
        
        // -------- Final Geometry --------
        let geometry           = SCNGeometry(sources: [posSource, colSource], elements: [element])
        geometry.firstMaterial = {
            let m                 = SCNMaterial()
            m.lightingModel       = .constant            // no shading; use vertex colour verbatim
            m.isDoubleSided       = true
            m.blendMode           = .alpha
            return m
        }()
        return geometry
    }
}

#Preview {
    Model3DViewer(scan: Scan.sample)
    //    PLYModelView(plyURL: Scan.samplePly.usdzURL)
}
