//
//  PointCloudScanner.swift
//  Capstone
//
//  Created by Seungwoo Choe on 2025-06-09.
//

import RealityKit
import ARKit
import OSLog

@Observable
class PointCloudScanner {
    
    private struct ColoredPoint {
        var xyz: SIMD3<Float>
        var rgb: SIMD3<UInt8>
    }
    
    private var points: [ColoredPoint] = []
    var isExportable: Bool {
        return !points.isEmpty
    }
    
    private let logger = Logger.forType(PointCloudScanner.self)
    
    func reset() {
        points.removeAll()
    }
    
    func addMeshAnchor(_ meshAnchor: ARMeshAnchor, frame: ARFrame, in arView: ARView) {
        let geometry    = meshAnchor.geometry
        let vertices    = geometry.vertices
        let vertexCount = vertices.count
        
        points.reserveCapacity(points.count + vertexCount)
        
        // Lock the camera image buffer
        let buffer = frame.capturedImage
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        
        let stride = vertices.stride
        let offset = vertices.offset
        let base   = vertices.buffer.contents()
        
        for i in 0..<vertexCount {
            let ptr = base.advanced(by: offset + i * stride)
                .assumingMemoryBound(to: SIMD3<Float>.self)
            let localPos = ptr.pointee
            let worldPos = meshAnchor.transform.transformPoint(localPos)
            
            guard let rgb = frame.sampleColor(atWorldPoint: worldPos, in: arView) else {
                continue
            }
            
            points.append(ColoredPoint(xyz: worldPos, rgb: rgb))
        }
    }
    
    func exportPLY() async throws -> URL {
        guard !points.isEmpty else {
            logger.error("No points to export!")
            throw NSError(domain: "PointCloudScanner", code: 1, userInfo: [NSLocalizedDescriptionKey: "No points available"])
        }
        
        logger.debug("Exporting \(self.points.count) coloured vertices…")
        
        // Header
        var plyText = """
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
        // Vertices
        for p in points {
            plyText += "\n\(p.xyz.x) \(p.xyz.y) \(p.xyz.z) \(p.rgb.x) \(p.rgb.y) \(p.rgb.z)"
        }
        
        let filename = "pointcloud.ply"
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(filename)
        
        try plyText.write(to: url, atomically: true, encoding: .ascii)
        return url
    }
}

// MARK: - Helper

extension simd_float4x4 {
    func transformPoint(_ p: SIMD3<Float>) -> SIMD3<Float> {
        let v4 = self * SIMD4<Float>(p, 1.0)
        return SIMD3<Float>(v4.x, v4.y, v4.z)
    }
}

// MARK: - Colour sampling

extension ARFrame {
    /// Projects a world‑space point into the camera image, samples its 8‑bit RGB.
    fileprivate func sampleColor(atWorldPoint world: SIMD3<Float>, in arView: ARView) -> SIMD3<UInt8>? {
        // 1) Get buffer dimensions
        let buffer = capturedImage
        let width  = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        
        // 2) Orientation & view size
        let orientation = (UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.interfaceOrientation }
            .first) ?? .portrait
        let viewSize = arView.bounds.size
        
        // 3) Project world → 2D view
        let projected = camera.projectPoint(world,
                                            orientation: orientation,
                                            viewportSize: viewSize)
        guard projected.x.isFinite, projected.y.isFinite else { return nil }
        
        // 4) Normalise to view-space (0…1)
        let norm = CGPoint(x: projected.x / viewSize.width,
                           y: projected.y / viewSize.height)
        
        // 5) Convert to normalised-image space
        let displayT = displayTransform(for: orientation,
                                        viewportSize: viewSize)
        let nImage = norm.applying(displayT.inverted())
        
        // 6) Pixel coords
        let px = Int((nImage.x * CGFloat(width)).rounded())
        let py = Int((nImage.y * CGFloat(height)).rounded())
        guard (0..<width).contains(px),
              (0..<height).contains(py) else { return nil }
        
        // 7) Sample YUV or BGRA
        switch CVPixelBufferGetPixelFormatType(buffer) {
            
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
        kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
            guard let yBase    = CVPixelBufferGetBaseAddressOfPlane(buffer, 0),
                  let cbcrBase = CVPixelBufferGetBaseAddressOfPlane(buffer, 1)
            else { return nil }
            let yStr  = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
            let cStr  = CVPixelBufferGetBytesPerRowOfPlane(buffer, 1)
            
            let yVal = yBase.advanced(by: py*yStr + px)
                .assumingMemoryBound(to: UInt8.self).pointee
            let cX   = px >> 1, cY = py >> 1
            let cbcr = cbcrBase.advanced(by: cY*cStr + cX*2)
                .assumingMemoryBound(to: UInt8.self)
            let cb = cbcr[0], cr = cbcr[1]
            
            // YUV → RGB (Rec.601)
            let Y = Float(yVal) - 16
            let U = Float(cb)   - 128
            let V = Float(cr)   - 128
            var r = 1.164*Y + 1.793*V
            var g = 1.164*Y - 0.213*U - 0.533*V
            var b = 1.164*Y + 2.112*U
            r = max(0, min(255, r))
            g = max(0, min(255, g))
            b = max(0, min(255, b))
            return SIMD3<UInt8>(UInt8(r), UInt8(g), UInt8(b))
            
        case kCVPixelFormatType_32BGRA:
            guard let base = CVPixelBufferGetBaseAddress(buffer) else {
                return nil
            }
            let stride = CVPixelBufferGetBytesPerRow(buffer)
            let ptr = base.advanced(by: py*stride + px*4)
                .assumingMemoryBound(to: UInt8.self)
            let blue  = ptr[0]
            let green = ptr[1]
            let red   = ptr[2]
            return SIMD3<UInt8>(red, green, blue)
            
        default:
            return nil
        }
    }
}
