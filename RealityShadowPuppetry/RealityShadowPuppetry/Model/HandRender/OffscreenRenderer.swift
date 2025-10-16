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
    let colorTexture: MTLTexture
    let camera = Entity()
    var useDefaultLight: Bool = true {
        didSet {
            if useDefaultLight {
                var lc = DirectionalLightComponent()
                lc.intensity = 5000
                lc.color = .white
                camera.components.set(lc)
            } else {
                camera.components.remove(DirectionalLightComponent.self)
            }
        }
    }
    var rendererUpdate: (() -> Void)?
    
    init(device: MTLDevice, textureSize: CGSize) throws {
        renderer = try RealityRenderer()
        
        var orthComponent = OrthographicCameraComponent()
        orthComponent.near = 0.1
        orthComponent.far = 100
        orthComponent.scale = 0.5
        
        camera.components.set(orthComponent)
        camera.position = [0, 0, 20]
        camera.name = "Camera"
//        camera.components.set(ModelComponent(mesh: .generateBox(size: 0.1), materials: [UnlitMaterial(color: .white)]))
        renderer.activeCamera = camera
        renderer.entities.append(camera)
        useDefaultLight = true
        
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
    func cameraAutoLookBoundingBoxCenter() {
        guard !renderer.entities.isEmpty else { return }
        let boundingBox = renderer.entities.reduce(renderer.entities.first!.visualBounds(relativeTo: nil)) { $0.union($1.visualBounds(relativeTo: nil)) }
        camera.look(at: boundingBox.center, from: boundingBox.center + SIMD3<Float>(0, 0, 20), relativeTo: nil)
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
    
    func render() throws {
        let cameraOutput = try RealityRenderer.CameraOutput(.singleProjection(colorTexture: colorTexture))
//        let c = colorTexture
//        try renderer.updateAndRender(deltaTime: 0, cameraOutput: cameraOutput)
        try renderer.updateAndRender(deltaTime: 0, cameraOutput: cameraOutput) {[weak self] render in
            Task {@MainActor in
                self?.rendererUpdate?()
            }
        }
    }
    func renderAsync() async throws {
        let cameraOutput = try RealityRenderer.CameraOutput(.singleProjection(colorTexture: colorTexture))
        try await withCheckedThrowingContinuation { continuation in
            do {
                try renderer.updateAndRender(deltaTime: 0, cameraOutput: cameraOutput) { render in
                    continuation.resume()
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
