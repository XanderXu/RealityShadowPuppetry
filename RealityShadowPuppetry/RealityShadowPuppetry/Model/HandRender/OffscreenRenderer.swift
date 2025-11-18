//
//  OffscreenRenderer.swift
//  RealityShadowPuppetry
//
//  Created by 许 on 2025/9/1.
//
@preconcurrency import RealityKit
import MetalKit

final class OffscreenRenderer: Sendable {
    private let renderer: RealityRenderer
    private let cameraAutoLookSuccessTimesLimit: Int = 5
    private var cameraAutoLookSuccessTimes: Int = 0
    private var cameraAutoLookFinashed: Bool = false
    
    
    let colorTexture: MTLTexture
    let camera = Entity()
    let light = DirectionalLight()
    
    // small value mean small viewport, but object will be larger in viewport
    var cameraScale: Float = 0.2 {
        didSet {
            var orthComponent = OrthographicCameraComponent()
            orthComponent.near = 0.1
            orthComponent.far = 100
            orthComponent.scale = cameraScale
            camera.components.set(orthComponent)
        }
    }
    var isRendering: Bool = false
    
    init(device: MTLDevice, textureSize: CGSize) throws {
        renderer = try RealityRenderer()
        
        var orthComponent = OrthographicCameraComponent()
        orthComponent.near = 0.1
        orthComponent.far = 100
        orthComponent.scale = 0.5
        
        camera.components.set(orthComponent)
        camera.position = [0, 0, 20]
        camera.name = "Camera"
        renderer.activeCamera = camera
        renderer.entities.append(camera)
        
        light.light.intensity = 5000
        light.light.color = .white
//        renderer.entities.append(light)
        camera.addChild(light)
        
        let textureDesc = MTLTextureDescriptor()
        textureDesc.pixelFormat = .rgba8Unorm
        textureDesc.width = Int(textureSize.width)
        textureDesc.height = Int(textureSize.height)
        textureDesc.usage = [.renderTarget, .shaderRead]
        
        colorTexture = device.makeTexture(descriptor: textureDesc)!
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
        renderer.entities.removeAll(where: { $0 == scene && $0 != renderer.activeCamera})
    }
    func removeAllEntities() {
        renderer.entities.removeAll(where: { $0 != renderer.activeCamera})
    }
    
    
    func renderAsync() async throws {
        if cameraAutoLookSuccessTimes < cameraAutoLookSuccessTimesLimit {
            let success = cameraLookAtBoundingBoxCenter()
            if success {
                cameraAutoLookSuccessTimes += 1
            }
        }
        let cameraOutput = try RealityRenderer.CameraOutput(.singleProjection(colorTexture: colorTexture))
        isRendering = true
        try await withCheckedThrowingContinuation { continuation in
            do {
                try renderer.updateAndRender(deltaTime: 0, cameraOutput: cameraOutput) { render in
                    self.isRendering = false
                    continuation.resume()
                }
            } catch {
                isRendering = false
                continuation.resume(throwing: error)
            }
        }
    }
}
