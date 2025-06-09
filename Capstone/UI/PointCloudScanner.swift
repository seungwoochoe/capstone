//
//  PointCloudScanner.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-06-09.
//

import Foundation
import RealityKit
import ARKit
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "PointCloudScanner")

/// Model object that gathers LiDAR mesh vertices (with per‑vertex colour)
/// and exports them as a PLY file. Works together with ARViewContainer
/// that feeds it `ARMeshAnchor` updates.
class PointCloudScanner: ObservableObject {
    // MARK: – Types
    struct ColoredPoint {
        var xyz: SIMD3<Float>
        var rgb: SIMD3<UInt8>
    }
    
    // MARK: – Published state
    @Published private(set) var isScanning: Bool = true
    
    // MARK: – Internal storage
    private var points: [ColoredPoint] = []
    
    // MARK: – Public helpers
    func reset() {
        points.removeAll()
        isScanning = true
    }
    
    /// Append vertices for the incoming mesh anchor.
    /// – Parameters:
    ///   - meshAnchor: anchor containing the LiDAR mesh chunk
    ///   - frame: latest ARFrame (for colour sampling)
    ///   - arView: the ARView whose camera is used when projecting to 2‑D
    func addMeshAnchor(_ meshAnchor: ARMeshAnchor, frame: ARFrame, in arView: ARView) {
        guard isScanning else { return }
        
        let geometry = meshAnchor.geometry
        let vertices = geometry.vertices
        let count    = vertices.count
        let stride   = vertices.stride
        let offset   = vertices.offset
        let buffer   = vertices.buffer.contents()
        
        for i in 0..<count {
            let ptr = buffer.advanced(by: offset + i * stride)
                .assumingMemoryBound(to: SIMD3<Float>.self)
            let localPosition  = ptr.pointee
            let worldPosition  = meshAnchor.transform.transformPoint(localPosition)
            
            guard let color = frame.sampleColor(atWorldPoint: worldPosition, in: arView) else {
                continue
            }
            points.append(ColoredPoint(xyz: worldPosition, rgb: color))
        }
    }
    
    /// Finishes the scan and writes a coloured ASCII‑PLY to /tmp, returning the URL.
    /// After export, `isScanning` becomes false until **reset()** is called.
    func exportPLY(completion: @escaping (URL?) -> Void) {
        // freeze
        isScanning = false
        
        guard !points.isEmpty else {
            logger.error("No points to export!")
            completion(nil)
            return
        }
        
        logger.debug("Exporting \(self.points.count) coloured vertices…")
        
        // Build header
        var ply = """
        ply
        format ascii 1.0
        element vertex \(points.count)
        property float x
        property float y
        property float z
        property uchar red
        property uchar green
        property uchar blue
        end_header
        """
        // Append vertices
        for p in points {
            ply += "\n\(p.xyz.x) \(p.xyz.y) \(p.xyz.z) \(p.rgb.x) \(p.rgb.y) \(p.rgb.z)"
        }
        
        let filename = "pointcloud.ply"
        let url      = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(filename)
        
        DispatchQueue.global(qos: .background).async {
            do {
                try ply.write(to: url, atomically: true, encoding: .ascii)
                DispatchQueue.main.async { completion(url) }
            } catch {
                logger.error("PLY export error: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }
}

// MARK: – Math helpers

extension simd_float4x4 {
    /// Multiplies 4×4 transform with a 3‑D point (implicit w = 1).
    func transformPoint(_ p: SIMD3<Float>) -> SIMD3<Float> {
        let v4 = self * SIMD4<Float>(p, 1.0)
        return SIMD3<Float>(v4.x, v4.y, v4.z)
    }
}

// MARK: – Colour sampling helper (ARFrame)

private extension ARFrame {
    /// Projects a world‑space point into the camera image, samples its 8‑bit RGB.
    /// Returns nil if the point is off‑screen, behind the camera, or if the buffer
    /// is in an unsupported format.
    func sampleColor(atWorldPoint world: SIMD3<Float>, in arView: ARView) -> SIMD3<UInt8>? {
        // 1) Get buffer dimensions
        let buffer = capturedImage
        let width  = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        
        // 2) Orientation & view size
        let orientation = (UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.interfaceOrientation }
            .first) ?? .portrait
        let viewSize = arView.bounds.size
        
        // 3) Project world → 2‑D view
        let projected = camera.projectPoint(world,
                                            orientation: orientation,
                                            viewportSize: viewSize)
        guard projected.x.isFinite, projected.y.isFinite else { return nil }
        
        // 4) Normalise to view‑space (0…1)
        let normalisedView = CGPoint(x: projected.x / viewSize.width,
                                     y: projected.y / viewSize.height)
        
        // 5) Convert to normalised‑image space
        let displayT = displayTransform(for: orientation, viewportSize: viewSize)
        let nImage   = normalisedView.applying(displayT.inverted())
        
        // 6) Pixel coordinates
        let px = Int((nImage.x * CGFloat(width)).rounded())
        let py = Int((nImage.y * CGFloat(height)).rounded())
        guard (0..<width).contains(px), (0..<height).contains(py) else { return nil }
        
        // 7) Sample YUV or BGRA
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        
        switch CVPixelBufferGetPixelFormatType(buffer) {
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
            guard let yBase = CVPixelBufferGetBaseAddressOfPlane(buffer, 0),
                  let cbcrBase = CVPixelBufferGetBaseAddressOfPlane(buffer, 1) else { return nil }
            let yStride    = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
            let cbcrStride = CVPixelBufferGetBytesPerRowOfPlane(buffer, 1)
            let yVal = yBase.advanced(by: py * yStride + px)
                .assumingMemoryBound(to: UInt8.self).pointee
            // subsampled chroma (4:2:0)
            let chromaX = px >> 1
            let chromaY = py >> 1
            let cbcrPtr = cbcrBase.advanced(by: chromaY * cbcrStride + chromaX * 2)
            let cb = cbcrPtr.assumingMemoryBound(to: UInt8.self)[0]
            let cr = cbcrPtr.assumingMemoryBound(to: UInt8.self)[1]
            // YUV → RGB (Rec.601)
            let Y = Float(yVal) - 16.0
            let U = Float(cb)   - 128.0
            let V = Float(cr)   - 128.0
            var r = 1.164 * Y + 1.793 * V
            var g = 1.164 * Y - 0.213 * U - 0.533 * V
            var b = 1.164 * Y + 2.112 * U
            r = max(0, min(255, r))
            g = max(0, min(255, g))
            b = max(0, min(255, b))
            return SIMD3<UInt8>(UInt8(r), UInt8(g), UInt8(b))
        case kCVPixelFormatType_32BGRA:
            guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
            let stride = CVPixelBufferGetBytesPerRow(buffer)
            let ptr    = base.advanced(by: py * stride + px * 4)
                .assumingMemoryBound(to: UInt8.self)
            let blue  = ptr[0]
            let green = ptr[1]
            let red   = ptr[2]
            return SIMD3<UInt8>(red, green, blue)
        default:
            return nil // unsupported format
        }
    }
}
