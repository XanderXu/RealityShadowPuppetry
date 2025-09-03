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
        
        let light = Entity()
        var lc = DirectionalLightComponent()
        lc.intensity = 5000
        lc.color = .white
        light.components.set(lc)
        light.position = [0, 0, 20]
        light.name = "Light"
        renderer.entities.append(light)
        
        var orthComponent = OrthographicCameraComponent()
        orthComponent.near = 0.1
        orthComponent.far = 100
        orthComponent.scale = 0.5
        
        camera = Entity()
        camera.components.set(orthComponent)
//        camera.position = [0, 0, 20]
        camera.name = "Camera"
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
        camera.look(at: scene.position, from: [0, scene.position.y, 20], relativeTo: nil)
    }
    func removeEntity(_ scene: Entity) {
        renderer.entities.removeAll(where: { $0 == scene && $0 != renderer.activeCamera })
    }
    func removeAllEntities() {
        renderer.entities.removeAll(where: { $0 != renderer.activeCamera })
    }
    @MainActor
    func render() throws {
        let cameraOutput = try RealityRenderer.CameraOutput(.singleProjection(colorTexture: colorTexture))
        let c = colorTexture
        try renderer.updateAndRender(deltaTime: 0, cameraOutput: cameraOutput)
    }
}
