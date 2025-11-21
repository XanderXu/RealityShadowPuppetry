//
//  StereoImageManager.swift
//  RealityShadowPuppetry
//
//  Created by 许 on 2025/11/20.
//

import RealityKit
import MetalKit
import RealityKitContent
import Combine

final class StereoImageManager {
    
    enum StereoStyle: String, CaseIterable {
        case Stereo
        case Left
        case Right
    }
    
    var mixedTextureEntity = ModelEntity()
    var stereoStyle = StereoStyle.Stereo {
        didSet {
            populateMPS(leftTexture: offscreenRenderer?.leftTexture, rightTexture: offscreenRenderer?.rightTexture, lowLevelTextureLeft: lltLeft, lowLevelTextureRight: lltRight, device: mtlDevice)
        }
    }
    
    
    private let mtlDevice = MTLCreateSystemDefaultDevice()!
    private let offscreenRenderer: StereoOffscreenRenderer?
    private let lltLeft: LowLevelTexture
    private let lltRight: LowLevelTexture
    private let sceneRoot = Entity()
    
    private var cancel: Cancellable?
    private var isProcessing: Bool = false
    
    init() async throws {
        let naturalSize = CGSize(width: 800, height: 800)
        offscreenRenderer = try StereoOffscreenRenderer(device: mtlDevice,textureSize: naturalSize)
        offscreenRenderer?.addEntity(sceneRoot)
        
        //An entity of a plane which uses the LowLevelTexture from mixedTexture.
        let textureDescriptor = Self.createTextureDescriptor(width: Int(naturalSize.width), height: Int(naturalSize.height))
        lltLeft = try LowLevelTexture(descriptor: textureDescriptor)
        lltRight = try LowLevelTexture(descriptor: textureDescriptor)
        
        // Create a TextureResource from the LowLevelTexture.
        let resourceLeft = try await TextureResource(from: lltLeft)
        let resourceRight = try await TextureResource(from: lltRight)
        
        // Create a shader graph material that uses the texture.
        var shaderGraphMaterial = try await ShaderGraphMaterial(named: "/Root/StereoMaterial", from: "Materials/StereoMaterial.usda", in: realityKitContentBundle)
        try shaderGraphMaterial.setParameter(name: "MonoImage", value: .textureResource(resourceLeft))
        try shaderGraphMaterial.setParameter(name: "LeftImage", value: .textureResource(resourceLeft))
        try shaderGraphMaterial.setParameter(name: "RightImage", value: .textureResource(resourceRight))

        // Return an entity of a plane which uses the generated texture.
        mixedTextureEntity.model = .init(mesh: .generatePlane(width: 1, height: Float(naturalSize.height/naturalSize.width)), materials: [shaderGraphMaterial])
        mixedTextureEntity.name = "MixedTexture"
        mixedTextureEntity.position = SIMD3(x: 0, y: 1, z: -2)
        
    }
    
    public func clean() {
        mixedTextureEntity.removeFromParent()
        sceneRoot.removeFromParent()
        cancel?.cancel()
        cancel = nil
    }
    public func loadModelEntity() async throws {
        let scene = try await Entity(named: "Scene/ArtistWorkflowExample", in: realityKitContentBundle)
        sceneRoot.addChild(scene)
        offscreenRenderer?.cameraLook(at: .one, from: [1, 1, 2])
    }
    
    public func play() {
        cancel = Timer.publish(every: 0.033, on: .main, in: .default).autoconnect().sink {_ in 
            self.sceneRoot.orientation *= simd_quatf(angle: -0.001, axis: SIMD3<Float>(0, 1, 0))
            Task {
                try? await self.renderTextureAsync()
            }
        }
        
    }
    
    public func pause() {
        sceneRoot.stopAllAnimations()
        cancel?.cancel()
        cancel = nil
    }

    public func renderTextureAsync() async throws {
        try await offscreenRenderer?.renderAsync()
        populateMPS(leftTexture: offscreenRenderer?.leftTexture, rightTexture: offscreenRenderer?.rightTexture, lowLevelTextureLeft: lltLeft, lowLevelTextureRight: lltRight, device: mtlDevice)
    }
    
    
    
    nonisolated
    private static func createTextureDescriptor(width: Int, height: Int) -> LowLevelTexture.Descriptor {
        var desc = LowLevelTexture.Descriptor()

        desc.textureType = .type2D
        desc.arrayLength = 1

        desc.width = width
        desc.height = height
        desc.depth = 1

        desc.mipmapLevelCount = 1
        desc.pixelFormat = .bgra8Unorm
        desc.textureUsage = [ .shaderWrite]
        desc.swizzle = .init(red: .red, green: .green, blue: .blue, alpha: .alpha)

        return desc
    }
    
    // MARK: - Texture Processing
    private func populateMPS(leftTexture: (any MTLTexture)?, rightTexture: (any MTLTexture)?, lowLevelTextureLeft: LowLevelTexture?, lowLevelTextureRight: LowLevelTexture?, device: MTLDevice?) {
        if isProcessing { return }
        
        guard let leftTexture, let rightTexture, let lowLevelTextureLeft, let lowLevelTextureRight, let device else { return }
        
        guard let commandQueue = device.makeCommandQueue(),
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            print("Failed to create command queue or command buffer")
            return
        }
        
        isProcessing = true
        let outTextureLeft = lowLevelTextureLeft.replace(using: commandBuffer)
        let outTextureRight = lowLevelTextureRight.replace(using: commandBuffer)
        
        switch stereoStyle {
        case .Stereo:
            copyTexture(from: leftTexture, to: outTextureLeft, commandBuffer: commandBuffer)
            copyTexture(from: rightTexture, to: outTextureRight, commandBuffer: commandBuffer)
        case .Left:
            copyTexture(from: leftTexture, to: outTextureLeft, commandBuffer: commandBuffer)
            copyTexture(from: leftTexture, to: outTextureRight, commandBuffer: commandBuffer)
        case .Right:
            copyTexture(from: rightTexture, to: outTextureLeft, commandBuffer: commandBuffer)
            copyTexture(from: rightTexture, to: outTextureRight, commandBuffer: commandBuffer)
        }
        
        
        commandBuffer.addCompletedHandler { cmdBuffer in
            let start = commandBuffer.gpuStartTime
            let end = commandBuffer.gpuEndTime
            let gpuRuntimeDuration = end - start
            print("GPU Runtime Duration: \(gpuRuntimeDuration)")
            
            self.isProcessing = false
        }
        commandBuffer.commit()
    }
    
    
    nonisolated
    private func copyTexture(from sourceTexture: MTLTexture, to destinationTexture: MTLTexture, commandBuffer: MTLCommandBuffer) {
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            print("Failed to create blit encoder")
            return
        }
        blitEncoder.copy(from: sourceTexture, to: destinationTexture)
        blitEncoder.endEncoding()
    }
}
