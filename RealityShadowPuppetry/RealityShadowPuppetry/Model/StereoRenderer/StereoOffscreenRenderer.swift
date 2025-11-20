//
//  StereoOffscreenRenderer.swift
//  RealityShadowPuppetry
//
//  Created by 许同学 on 2025/11/20.
//

@preconcurrency import RealityKit
import MetalKit

final class StereoOffscreenRenderer: Sendable {
    private let renderer: RealityRenderer
    
    let leftTexture: MTLTexture
    let rightTexture: MTLTexture
    let camera = Entity()
    let cameraLeft = PerspectiveCamera()
    let cameraRight = PerspectiveCamera()
    let light = DirectionalLight()
    
    
    var isRendering: Bool {
        return isRenderingLeft || isRenderingRight
    }
    private var isRenderingLeft: Bool = false
    private var isRenderingRight: Bool = false
    private let cameraOutputLeft: RealityRenderer.CameraOutput
    private let cameraOutputRight: RealityRenderer.CameraOutput
    
    init(device: MTLDevice, textureSize: CGSize) throws {
        renderer = try RealityRenderer()
        renderer.activeCamera = cameraLeft
        renderer.entities.append(camera)
        
        camera.position = [0, 0, 20]
        camera.name = "Camera"
        cameraLeft.position = [-0.05, 0, 0]
        cameraRight.position = [0.05, 0, 0]
        camera.addChild(cameraLeft)
        camera.addChild(cameraRight)
        
        light.light.intensity = 5000
        light.light.color = .white
        camera.addChild(light)
        
        let textureDesc = MTLTextureDescriptor()
        textureDesc.pixelFormat = .rgba8Unorm
        textureDesc.width = Int(textureSize.width)
        textureDesc.height = Int(textureSize.height)
        textureDesc.usage = [.renderTarget, .shaderRead]
        
        leftTexture = device.makeTexture(descriptor: textureDesc)!
        rightTexture = device.makeTexture(descriptor: textureDesc)!
        
        cameraOutputLeft = try RealityRenderer.CameraOutput(.singleProjection(colorTexture: leftTexture))
        cameraOutputRight = try RealityRenderer.CameraOutput(.singleProjection(colorTexture: rightTexture))
    }
    func cameraLook(at position: SIMD3<Float>, from: SIMD3<Float>, relativeTo: Entity? = nil) {
        camera.look(at: position, from: from, relativeTo: relativeTo)
    }
    
    @discardableResult
    func cameraLookAtBoundingBoxCenter() -> Bool {
        guard !renderer.entities.isEmpty else { return false}
        let boundingBox = renderer.entities.reduce(renderer.entities.first!.visualBounds(relativeTo: nil)) { $0.union($1.visualBounds(relativeTo: nil)) }
        print(boundingBox.center, boundingBox.extents)
        if boundingBox.isEmpty { return false}
        camera.look(at: boundingBox.center, from: boundingBox.center + SIMD3<Float>(0, 0, 50), relativeTo: nil)
        return true
    }
    
    func addEntity(_ scene: Entity) {
        renderer.entities.append(scene)
    }
    func removeEntity(_ scene: Entity) {
        renderer.entities.removeAll(where: { $0 == scene && $0 != renderer.activeCamera?.parent})
    }
    func removeAllEntities() {
        renderer.entities.removeAll(where: { $0 != renderer.activeCamera?.parent})
    }
    func renderLeft() async throws {
        isRenderingLeft = true
        try await withCheckedThrowingContinuation { continuation in
            do {
                renderer.activeCamera = cameraLeft
                try renderer.updateAndRender(deltaTime: 0, cameraOutput: cameraOutputLeft) { render in
                    self.isRenderingLeft = false
                    continuation.resume()
                }
            } catch {
                isRenderingLeft = false
                continuation.resume(throwing: error)
            }
        }
    }
    func renderRight() async throws {
        isRenderingRight = true
        try await withCheckedThrowingContinuation { continuation in
            do {
                renderer.activeCamera = cameraRight
                try renderer.updateAndRender(deltaTime: 0, cameraOutput: cameraOutputRight) { render in
                    self.isRenderingRight = false
                    continuation.resume()
                }
            } catch {
                isRenderingRight = false
                continuation.resume(throwing: error)
            }
        }
    }
    
    func renderAsync() async throws {
        if isRendering { return }
        try await renderLeft()
        try await renderRight()
    }
}
