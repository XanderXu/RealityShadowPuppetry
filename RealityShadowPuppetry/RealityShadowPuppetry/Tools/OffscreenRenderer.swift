//
//  OffscreenRenderer.swift
//  RealityShadowPuppetry
//
//  Created by 许M4 on 2025/9/1.
//
@preconcurrency import RealityKit
import MetalKit

@MainActor
final class OffscreenRenderer {
    private let renderer: RealityRenderer
    let colorTexture: MTLTexture
    let camera: Entity
        
    init(device: MTLDevice, textureSize: CGSize) throws {
        renderer = try RealityRenderer()
        
        var orthComponent = OrthographicCameraComponent()
        orthComponent.near = 0.1
        orthComponent.far = 100
        orthComponent.scale = 1
        
        camera = Entity()
        camera.components.set(orthComponent)
        renderer.activeCamera = camera
        renderer.entities.append(camera)
        
        let textureDesc = MTLTextureDescriptor()
        textureDesc.pixelFormat = .rgba8Unorm
        textureDesc.width = Int(textureSize.width)
        textureDesc.height = Int(textureSize.height)
        textureDesc.usage = [.renderTarget, .shaderRead]
        
        colorTexture = device.makeTexture(descriptor: textureDesc)!
    }
    
    func addEntity(_ scene: Entity) {
        renderer.entities.append(scene)
    }
    func removeEntity(_ scene: Entity) {
        renderer.entities.removeAll(where: { $0 == scene })
    }
    func removeAllEntities() {
        renderer.entities.removeAll(where: { $0 != renderer.activeCamera })
    }
    
    func render() throws {
        let cameraOutput = try RealityRenderer.CameraOutput(.singleProjection(colorTexture: colorTexture))
        try renderer.updateAndRender(deltaTime: 0, cameraOutput: cameraOutput)
    }
}
