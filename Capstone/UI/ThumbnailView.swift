//
//  ThumbnailView.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-05-06.
//

import SwiftUI
import SceneKit
import OSLog

struct ThumbnailView: View {
    
    let url: URL
    let size: CGSize
    
    @State private var thumbnail: UIImage?
    @State private var isGenerating = false
    
    private let logger = Logger.forType(ThumbnailView.self)
    
    private static let imageCache: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.totalCostLimit = 50 * 1_024 * 1_024 // 50 MB
        cache.countLimit = 100
        return cache
    }()
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
            
            if let img = thumbnail {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else if isGenerating {
                ProgressView()
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
}

// MARK: - Helpers

private extension ThumbnailView {
    
    func generateThumbnail() async {
        if let cached = Self.imageCache.object(forKey: url as NSURL) {
            await MainActor.run {
                self.thumbnail = cached
            }
            return
        }
        await MainActor.run {
            self.isGenerating = true
        }
        
        do {
            let scene = try await makeScene(for: url)
            let renderer = try makeRenderer(for: scene)
            let image = snapshot(from: renderer)
            
            Self.imageCache.setObject(image, forKey: url as NSURL)
            await MainActor.run {
                self.thumbnail = image
                self.isGenerating = false
            }
        } catch {
            logger.error("Thumbnail generation failed: \(error.localizedDescription, privacy: .public)")
            await MainActor.run {
                self.isGenerating = false
            }
        }
    }
    
    func makeScene(for url: URL) async throws -> SCNScene {
        switch url.pathExtension.lowercased() {
        case "ply":
            return try makePLYScene(from: url)
        default:
            // Fallback to SceneKit’s built‑in importer (USDZ, OBJ, etc.)
            return try SCNScene(url: url, options: nil)
        }
    }
    
    /// Parses a PLY point‑cloud and returns a minimal SceneKit scene.
    /// The loader is designed for speed: it memory‑maps the file and samples
    /// the vertex stream instead of loading every single point.
    func makePLYScene(from url: URL, maxPoints: Int = 20_000) throws -> SCNScene {
        
        struct Header {
            var vertexCount = 0
            var hasColor = false
            var headerSize = 0
            var isBinaryLE = false
        }
        
        // 1. Read header
        let fileData = try Data(contentsOf: url, options: .mappedIfSafe)
        let header: Header = fileData.withUnsafeBytes { rawPtr in
            var p = rawPtr.bindMemory(to: UInt8.self).baseAddress!
            var bytes = 0
            var h = Header()
            func line() -> String {
                var d = Data()
                while p.pointee != 0x0A { d.append(p, count: 1); p = p.advanced(by: 1); bytes += 1 }
                p = p.advanced(by: 1); bytes += 1 // skip newline
                return String(data: d, encoding: .ascii) ?? ""
            }
            _ = line() // "ply"
            while true {
                let l = line()
                if l.hasPrefix("format binary_little_endian") {
                    h.isBinaryLE = true
                } else if l.hasPrefix("element vertex") {
                    h.vertexCount = Int(l.split(separator: " ")[2]) ?? 0
                } else if l.hasPrefix("property uchar red") {
                    h.hasColor = true
                } else if l == "end_header" {
                    h.headerSize = bytes; break
                }
            }
            return h
        }
        guard header.vertexCount > 0 else {
            throw NSError(domain: "ThumbnailView", code: -1, userInfo: [NSLocalizedDescriptionKey: "PLY header missing vertex count"])
        }
        
        // 2. Reservoir‑sample the vertex section
        var positions = [SIMD3<Float>](); positions.reserveCapacity(min(header.vertexCount, maxPoints))
        var colors = header.hasColor ? [SIMD4<Float>]() : []
        if header.hasColor { colors.reserveCapacity(positions.capacity) }
        let keepProb = Double(maxPoints) / Double(header.vertexCount)
        
        if header.isBinaryLE {
            fileData.withUnsafeBytes { rawPtr in
                var cursor = rawPtr.baseAddress!.advanced(by: header.headerSize)
                for _ in 0..<header.vertexCount {
                    if Double.random(in: 0...1) <= keepProb {
                        let x = cursor.load(as: Float.self)
                        let y = cursor.load(fromByteOffset: 4, as: Float.self)
                        let z = cursor.load(fromByteOffset: 8, as: Float.self)
                        positions.append(SIMD3(x, y, z))
                        if header.hasColor {
                            let r = Float(cursor.load(fromByteOffset: 12, as: UInt8.self)) / 255.0
                            let g = Float(cursor.load(fromByteOffset: 13, as: UInt8.self)) / 255.0
                            let b = Float(cursor.load(fromByteOffset: 14, as: UInt8.self)) / 255.0
                            colors.append(SIMD4(r, g, b, 1))
                        }
                    }
                    cursor = cursor.advanced(by: header.hasColor ? 15 : 12)
                }
            }
        } else {
            // ASCII
            let ascii = String(decoding: fileData.dropFirst(header.headerSize), as: UTF8.self)
            var processed = 0
            ascii.enumerateLines { line, stop in
                guard processed < header.vertexCount else { stop = true; return }
                processed += 1
                if Double.random(in: 0...1) > keepProb { return }
                let comps = line.split(separator: " ")
                guard comps.count >= 3 else { return }
                let x = Float(comps[0]) ?? 0, y = Float(comps[1]) ?? 0, z = Float(comps[2]) ?? 0
                positions.append(SIMD3(x, y, z))
                if header.hasColor, comps.count >= 6 {
                    let r = Float(Int(comps[3]) ?? 0) / 255.0
                    let g = Float(Int(comps[4]) ?? 0) / 255.0
                    let b = Float(Int(comps[5]) ?? 0) / 255.0
                    colors.append(SIMD4(r, g, b, 1))
                }
            }
        }
        
        // 3. Build SceneKit geometry (points)
        let posData = positions.withUnsafeBufferPointer { Data(buffer: $0) }
        let posSource = SCNGeometrySource(data: posData,
                                          semantic: .vertex,
                                          vectorCount: positions.count,
                                          usesFloatComponents: true,
                                          componentsPerVector: 3,
                                          bytesPerComponent: MemoryLayout<Float>.size,
                                          dataOffset: 0,
                                          dataStride: MemoryLayout<SIMD3<Float>>.size)
        var sources: [SCNGeometrySource] = [posSource]
        if header.hasColor, colors.count == positions.count {
            let colData = colors.withUnsafeBufferPointer { Data(buffer: $0) }
            let colSource = SCNGeometrySource(data: colData,
                                              semantic: .color,
                                              vectorCount: colors.count,
                                              usesFloatComponents: true,
                                              componentsPerVector: 4,
                                              bytesPerComponent: MemoryLayout<Float>.size,
                                              dataOffset: 0,
                                              dataStride: MemoryLayout<SIMD4<Float>>.size)
            sources.append(colSource)
        }
        let indices = (0..<positions.count).map { UInt32($0) }
        let idxData = indices.withUnsafeBufferPointer { Data(buffer: $0) }
        let element = SCNGeometryElement(data: idxData,
                                         primitiveType: .point,
                                         primitiveCount: positions.count,
                                         bytesPerIndex: MemoryLayout<UInt32>.size)
        element.minimumPointScreenSpaceRadius = 1
        element.maximumPointScreenSpaceRadius = 4
        let geometry = SCNGeometry(sources: sources, elements: [element])
        geometry.materials = { let m = SCNMaterial(); m.lightingModel = .constant; return [m] }()
        
        let node = SCNNode(geometry: geometry)
        node.name = "PointCloud"
        let scene = SCNScene()
        scene.rootNode.addChildNode(node)
        return scene
    }
    
    func makeRenderer(for scene: SCNScene) throws -> SCNRenderer {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw NSError(domain: "ThumbnailView", code: -2, userInfo: [NSLocalizedDescriptionKey: "Metal unavailable"])
        }
        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = scene
        
        let (center, radius) = scene.rootNode.boundingSphere
        let distance = radius * 1.3
        let camNode = SCNNode()
        camNode.name = "thumb‑cam"
        camNode.camera = {
            let c = SCNCamera(); c.fieldOfView = 55; return c
        }()
        camNode.position = SCNVector3(center.x + distance, center.y + distance * 0.25, center.z + distance)
        camNode.look(at: center)
        scene.rootNode.addChildNode(camNode)
        renderer.pointOfView = camNode
        
        // Soft ambient for silhouette‑only rendering
        let ambient = SCNLight(); ambient.type = .ambient; ambient.intensity = 400
        let ambNode = SCNNode(); ambNode.light = ambient; scene.rootNode.addChildNode(ambNode)
        return renderer
    }
    
    func snapshot(from renderer: SCNRenderer) -> UIImage {
        let scale = UIScreen.main.scale
        let renderSize = CGSize(width: size.width * scale, height: size.height * scale)
        let img = renderer.snapshot(atTime: 0, with: renderSize, antialiasingMode: .multisampling4X)
        return UIImage(cgImage: img.cgImage!, scale: scale, orientation: .up)
    }
}
