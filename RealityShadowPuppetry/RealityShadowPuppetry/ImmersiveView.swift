//
//  ImmersiveView.swift
//  RealityShadowPuppetry
//
//  Created by 许M4 on 2025/6/16.
//

import SwiftUI
import RealityKit
import RealityKitContent
import MetalPerformanceShaders
import MetalKit

struct ImmersiveView: View {
    var textureDescriptor: LowLevelTexture.Descriptor {
        var desc = LowLevelTexture.Descriptor()


        desc.textureType = .type2D
        desc.arrayLength = 1


        desc.width = 2048
        desc.height = 2048
        desc.depth = 1


        desc.mipmapLevelCount = 1
        desc.pixelFormat = .bgra8Unorm
        desc.textureUsage = [.shaderRead, .shaderWrite]
        desc.swizzle = .init(red: .red, green: .green, blue: .blue, alpha: .alpha)


        return desc
    }
    var inTexture: MTLTexture {
        let textureLoader = MTKTextureLoader(device: MTLCreateSystemDefaultDevice()!)
        let texture: MTLTexture = try! textureLoader.newTexture(name: "panghu", scaleFactor: 1, bundle: nil)
        return texture
    }
    var body: some View {
        RealityView { content in
            do {
                let texture = try LowLevelTexture(descriptor: textureDescriptor)
                let resource = try TextureResource(from: texture)
                
                let planeEntity = try textureEntity(device: MTLCreateSystemDefaultDevice()!)
                content.add(planeEntity)
            } catch {
                print(error)
            }
            
        }
    }
    
    func textureEntity(device: MTLDevice) throws -> Entity {
        // Create the LowLevelTexture and populate it on the GPU.
        let texture = try LowLevelTexture(descriptor: textureDescriptor)
        populate(texture: texture, device: device)


        // Create a TextureResource from the LowLevelTexture.
        let resource = try TextureResource(from: texture)


        // Create a material that uses the texture.
        var material = UnlitMaterial(texture: resource)
        material.opacityThreshold = 0.5


        // Return an entity of a plane which uses the generated texture.
        return ModelEntity(mesh: .generatePlane(width: 1, height: 1), materials: [material])
    }
    
    func populate(texture: LowLevelTexture, device: MTLDevice) {
        // Set up the Metal command queue and compute command encoder,
        // or abort if that fails.
        guard let commandQueue = device.makeCommandQueue(),
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }
        
        // Create a MPS filter.
        let blur = MPSImageGaussianBlur(device: device, sigma: 8)
        let t = texture.replace(using: commandBuffer)
        
        blur.encode(commandBuffer: commandBuffer, sourceTexture: inTexture, destinationTexture: t)
        // The usual Metal enqueue process.
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environment(AppModel())
}
