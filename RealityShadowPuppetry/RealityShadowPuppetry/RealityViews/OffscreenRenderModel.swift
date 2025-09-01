//
//  OffscreenRenderModel.swift
//  RealityShadowPuppetry
//
//  Created by 许M4 on 2025/9/1.
//
@preconcurrency import RealityKit
import MetalKit

@Observable
@MainActor
final class OffscreenRenderModel {
        
    private let renderer: RealityRenderer
    
    let colorTexture: MTLTexture
        
    init(scene: Entity, device: MTLDevice, textureSize: SIMD2<Int>) throws {
        renderer = try RealityRenderer()
        
        renderer.entities.append(scene)
        
        let camera = PerspectiveCamera()
        renderer.activeCamera = camera
        renderer.entities.append(camera)
        
        let textureDesc = MTLTextureDescriptor()
        textureDesc.pixelFormat = .rgba8Unorm
        textureDesc.width = textureSize.x
        textureDesc.height = textureSize.y
        textureDesc.usage = [.renderTarget, .shaderRead]
        
        colorTexture = device.makeTexture(descriptor: textureDesc)!
    }
    
    func render() throws {
        
        let cameraOutputDesc = RealityRenderer.CameraOutput.Descriptor.singleProjection(colorTexture: colorTexture)
        
        let cameraOutput = try RealityRenderer.CameraOutput(cameraOutputDesc)
 
        try renderer.updateAndRender(deltaTime: 0.1, cameraOutput: cameraOutput, onComplete: { renderer in
            
            guard let colorTexture = cameraOutput.colorTextures.first else { fatalError() }
            
            // The colorTexture holds the rendered scene.
        })
    }
}
