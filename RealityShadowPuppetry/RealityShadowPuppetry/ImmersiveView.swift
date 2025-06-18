//
//  ImmersiveView.swift
//  RealityShadowPuppetry
//
//  Created by 许M4 on 2025/6/16.
//

import SwiftUI
import RealityKit
import MetalPerformanceShaders
import MetalKit

struct ImmersiveView: View {
    var body: some View {
        RealityView { content in
            do {
                let planeEntity = try textureEntity(device: MTLCreateSystemDefaultDevice()!, imageName: "panghu")
                content.add(planeEntity)
            } catch {
                print(error)
            }
            
        }
    }
    func createTextureDescriptor(width: Int, height: Int) -> LowLevelTexture.Descriptor {
        var desc = LowLevelTexture.Descriptor()

        desc.textureType = .type2D
        desc.arrayLength = 1

        desc.width = width
        desc.height = height
        desc.depth = 1

        desc.mipmapLevelCount = 1
        desc.pixelFormat = .bgra8Unorm
        desc.textureUsage = [.shaderRead, .shaderWrite]
        desc.swizzle = .init(red: .red, green: .green, blue: .blue, alpha: .alpha)

        return desc
    }
    
    func textureEntity(device: MTLDevice, imageName: String) throws -> Entity {
        // Load the input texture.
        let textureLoader = MTKTextureLoader(device: device)
        let inTexture: MTLTexture = try textureLoader.newTexture(name: imageName, scaleFactor: 1, bundle: nil)
        
        // Create a descriptor for the LowLevelTexture.
        let textureDescriptor = createTextureDescriptor(width: inTexture.width, height: inTexture.height)
        // Create the LowLevelTexture and populate it on the GPU.
        let llt = try LowLevelTexture(descriptor: textureDescriptor)
        
        
//        populateMPS(inTexture: inTexture, lowLevelTexture: llt, device: device)
        populateCIFilter(inTexture: inTexture, lowLevelTexture: llt, device: device)

        // Create a TextureResource from the LowLevelTexture.
        let resource = try TextureResource(from: llt)
        // Create a material that uses the texture.
        var material = UnlitMaterial(texture: resource)
        material.opacityThreshold = 0.5

        // Return an entity of a plane which uses the generated texture.
        return ModelEntity(mesh: .generatePlane(width: 1, height: 1), materials: [material])
    }
    
    func populateMPS(inTexture: MTLTexture, lowLevelTexture: LowLevelTexture, device: MTLDevice) {
        // Set up the Metal command queue and compute command encoder,
        // or abort if that fails.
        guard let commandQueue = device.makeCommandQueue(),
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }
        
        // Create a MPS filter.
        let blur = MPSImageGaussianBlur(device: device, sigma: 8)
        // set input output
        let outTexture = lowLevelTexture.replace(using: commandBuffer)
        blur.encode(commandBuffer: commandBuffer, sourceTexture: inTexture, destinationTexture: outTexture)
        
        // The usual Metal enqueue process.
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    func populateCIFilter(inTexture: MTLTexture, lowLevelTexture: LowLevelTexture, device: MTLDevice) {
        // Set up the Metal command queue and compute command encoder,
        // or abort if that fails.
        guard let commandQueue = device.makeCommandQueue(),
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }
        
        // Create a CIFilter.
        let blur = CIFilter(name: "CIGaussianBlur")
        blur?.setValue(CIImage(mtlTexture: inTexture), forKey: kCIInputImageKey)
        blur?.setValue(8, forKey: kCIInputRadiusKey)
        
        // set input output
        let outTexture = lowLevelTexture.replace(using: commandBuffer)
        let render = CIRenderDestination(mtlTexture: outTexture, commandBuffer: commandBuffer)
        // Create a Context for GPU-Based Rendering
        let ciContext = CIContext(mtlCommandQueue: commandQueue)
        if let outImage = blur?.outputImage {
            do {
                try ciContext.startTask(toRender: outImage, to: render)
            } catch  {
                print(error)
            }
        }
        
        // The usual Metal enqueue process.
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environment(AppModel())
}
