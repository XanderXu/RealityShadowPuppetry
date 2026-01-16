//
//  ShadowMixManager.swift
//  RealityShadowPuppetry
//
//  Created by 许 on 2025/9/2.
//

import RealityKit
@preconcurrency import MetalKit
@preconcurrency import AVFoundation
import MetalPerformanceShaders
import ARKit

// Processing state manager using actor for thread safety
actor ProcessingStateManager {
    private var isProcessing: Bool = false

    func tryStartProcessing() -> Bool {
        guard !isProcessing else { return false }
        isProcessing = true
        return true
    }

    func finishProcessing() {
        isProcessing = false
    }
}

final class ShadowMixManager {
    enum TrackingType: String, CaseIterable {
        case hand
        case body
    }
    enum ShadowMixStyle: String, CaseIterable {
        case ColorAdd
        case GrayAdd
        case GrayMixRed
    }
    
    let originalVideoEntity = ModelEntity()
    let originalTransparentVideoEntity = ModelEntity()
    let mixedTextureEntity = ModelEntity()
    var shadowStyle = ShadowMixStyle.GrayAdd
    var trackingType: TrackingType = .hand
    
    var rootEntity: Entity {
        switch trackingType {
        case .hand:
            return handEntityManager.rootEntity
        case .body:
            return bodyEntityManager.rootEntity
        }
    }
    
    private let mtlDevice: MTLDevice
    private let offscreenRenderer: OffscreenRenderer?
    private let llt: LowLevelTexture
    private(set) var videoPlayAndRenderCenter: VideoPlayAndRenderCenter?

    private let handEntityManager: HandEntityManager
    private let bodyEntityManager: BodyEntityManager

    // MARK: - Private Properties
    private var grayMixRedPipelineState: MTLComputePipelineState?
    private let processingStateManager = ProcessingStateManager()
    
    init(asset: AVAsset, trackingType: TrackingType) async throws {
        bodyEntityManager = BodyEntityManager()
        handEntityManager = HandEntityManager()
        self.trackingType = trackingType

        // Create Metal device
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw NSError(domain: "ShadowMixManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create Metal device"])
        }
        self.mtlDevice = device

        // Initialize compute pipeline state
        grayMixRedPipelineState = Self.createGrayMixRedComputePipelineState(device: mtlDevice)
        videoPlayAndRenderCenter = try await VideoPlayAndRenderCenter(asset: asset)

        // Load video track
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw NSError(domain: "ShadowMixManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "No video track found in asset"])
        }
        let naturalSize = try await videoTrack.load(.naturalSize)
        
        offscreenRenderer = try OffscreenRenderer(device: mtlDevice,textureSize: naturalSize)
        switch trackingType {
        case .hand:
            offscreenRenderer?.addEntity(handEntityManager.rootEntity)
        case .body:
            offscreenRenderer?.addEntity(bodyEntityManager.rootEntity)
        }
        
        //An entity of a plane which uses the LowLevelTexture from mixedTexture.
        let textureDescriptor = Self.createTextureDescriptor(width: Int(naturalSize.width), height: Int(naturalSize.height))
        llt = try LowLevelTexture(descriptor: textureDescriptor)

        // Validate players are created
        guard let player = videoPlayAndRenderCenter?.player, let transparentPlayer = videoPlayAndRenderCenter?.transparentPlayer else {
            throw NSError(domain: "ShadowMixManager", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to create video players"])
        }
        
        //An entity of a plane which uses the VideoMaterial.
        let videoMaterial = VideoMaterial(avPlayer: player)
        originalVideoEntity.model = .init(mesh: .generatePlane(width: 1, height: Float(naturalSize.height/naturalSize.width)), materials: [videoMaterial])
        originalVideoEntity.name = "OriginalVideo"
        originalVideoEntity.position = SIMD3(x: 1.2, y: 1, z: -2)
        
        //An entity of a plane which uses the VideoMaterial.
        let videoMaterial2 = VideoMaterial(avPlayer: transparentPlayer)
        originalTransparentVideoEntity.model = .init(mesh: .generatePlane(width: 1, height: Float(naturalSize.height/naturalSize.width)), materials: [videoMaterial2])
        originalTransparentVideoEntity.name = "OriginalVideo"
        originalTransparentVideoEntity.position = SIMD3(x: 1.2, y: 1, z: -2)
        
        let resource = try await TextureResource(from: llt)
        var material = UnlitMaterial(texture: resource)
        material.opacityThreshold = 0.01
        mixedTextureEntity.model = .init(mesh: .generatePlane(width: 1, height: Float(naturalSize.height/naturalSize.width)), materials: [material])
        mixedTextureEntity.name = "MixedTexture"
        mixedTextureEntity.position = SIMD3(x: 0, y: 1, z: -2)
        
        videoPlayAndRenderCenter?.videoPixelUpdate = { [weak self] in
            Task.detached(priority: .userInitiated) { [weak self] in
                await self?.populateMPS(videoTexture: self?.videoPlayAndRenderCenter?.lastestPixel,
                        offscreenTexture: self?.offscreenRenderer?.colorTexture,
                        lowLevelTexture: self?.llt,
                        device: self?.mtlDevice)
            }
        }
    }
    
    public func clean() {
        bodyEntityManager.clean()
        handEntityManager.clean()
        videoPlayAndRenderCenter?.clean()
        originalVideoEntity.removeFromParent()
        originalTransparentVideoEntity.removeFromParent()
        mixedTextureEntity.removeFromParent()
    }
    public func loadHandModelEntity() async throws {
        offscreenRenderer?.cameraScale = 0.15
        try await handEntityManager.loadHandModelEntity()
    }
    public func loadBodyModelEntity() async throws {
        offscreenRenderer?.cameraScale = 1.25
        try await bodyEntityManager.loadBodyModelEntity()
    }
    
    
    public func updateEntity(from handAnchor: HandAnchor, deviceMatrix: simd_float4x4?) async {
        switch trackingType {
        case .hand:
            handEntityManager.updateHandModel(from: handAnchor)
        case .body:
            bodyEntityManager.updateBodyModel(from: handAnchor, deviceMatrix: deviceMatrix)
        }
    }
    
    public func removeEntity(from handAnchor: HandAnchor) {
        switch trackingType {
        case .hand:
            handEntityManager.removeHand(from: handAnchor)
        case .body:
            bodyEntityManager.removeBody(from: handAnchor)
        }
    }
    
    public func updateHand(from simHand: SimHand) async {
        await handEntityManager.updateHand(from: simHand)
    }
    
    public func cameraLookAtHandCenter() {
        offscreenRenderer?.cameraLookAtBoundingBoxCenter()
    }

    public func renderEntityShadowTextureAsync() async throws {
        try await offscreenRenderer?.renderAsync()
    }
    
    public func renderSimHandTextureAsync() async throws {
        offscreenRenderer?.addEntity(handEntityManager.rootEntity)
        offscreenRenderer?.cameraLook(at: SIMD3<Float>(0, 1.4, 0), from: SIMD3<Float>(0, 1.4, 20))
        try await offscreenRenderer?.renderAsync()
    }
    

    public func populateFinalShadowIfNeeded() {
        guard videoPlayAndRenderCenter?.player?.timeControlStatus != .playing else { return }

        Task.detached(priority: .userInitiated) { [weak self] in
            await self?.populateMPS(videoTexture: self?.videoPlayAndRenderCenter?.lastestPixel,
                    offscreenTexture: self?.offscreenRenderer?.colorTexture,
                    lowLevelTexture: self?.llt,
                    device: self?.mtlDevice)
        }
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
    
    // MARK: - Metal Shader Setup
    nonisolated
    private static func createGrayMixRedComputePipelineState(device: MTLDevice) -> MTLComputePipelineState? {
        guard let defaultLibrary = device.makeDefaultLibrary(),
              let kernelFunction = defaultLibrary.makeFunction(name: "grayMixRedKernel") else {
            print("Failed to create grayMixRedKernel function from default library")
            return nil
        }
        
        do {
            return try device.makeComputePipelineState(function: kernelFunction)
        } catch {
            print("Failed to create compute pipeline state: \(error)")
            return nil
        }
    }
    
    // MARK: - Texture Processing
    private func populateMPS(videoTexture: (any MTLTexture)?, offscreenTexture: (any MTLTexture)?, lowLevelTexture: LowLevelTexture?, device: MTLDevice?) async {
        // Thread-safe check and set of isProcessing flag using actor
        let shouldProcess = await processingStateManager.tryStartProcessing()
        guard shouldProcess else { return }

        // Ensure processing state is reset even if errors occur
        defer {
            Task {
                await processingStateManager.finishProcessing()
            }
        }

        guard let lowLevelTexture = lowLevelTexture,
              let device = device,
              let offscreenTexture = offscreenTexture else {
            return
        }

        guard let commandQueue = device.makeCommandQueue(),
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            print("Failed to create command queue or command buffer")
            return
        }

        let outTexture = lowLevelTexture.replace(using: commandBuffer)

        // Capture current style to avoid actor isolation issues
        let currentStyle = shadowStyle

        switch currentStyle {
        case .ColorAdd:
            processColorAdd(videoTexture: videoTexture, offscreenTexture: offscreenTexture, outputTexture: outTexture, commandBuffer: commandBuffer, device: device)

        case .GrayAdd:
            processGrayAdd(videoTexture: videoTexture, offscreenTexture: offscreenTexture, outputTexture: outTexture, commandBuffer: commandBuffer, device: device)

        case .GrayMixRed:
            processGrayMixRed(videoTexture: videoTexture, offscreenTexture: offscreenTexture, outputTexture: outTexture, commandBuffer: commandBuffer, device: device)
        }

        // Use async continuation to wait for GPU completion
        await withCheckedContinuation { continuation in
            commandBuffer.addCompletedHandler { cmdBuffer in
                let start = commandBuffer.gpuStartTime
                let end = commandBuffer.gpuEndTime
                let gpuRuntimeDuration = end - start
                print("GPU Runtime Duration: \(gpuRuntimeDuration)")

                continuation.resume()
            }
            commandBuffer.commit()
        }
    }
    
    // MARK: - Processing Methods
    nonisolated
    private func processColorAdd(videoTexture: (any MTLTexture)?, offscreenTexture: MTLTexture, outputTexture: MTLTexture, commandBuffer: MTLCommandBuffer, device: MTLDevice) {
        if let videoTexture = videoTexture {
            let add = MPSImageAdd(device: device)
            add.encode(commandBuffer: commandBuffer, primaryTexture: videoTexture, secondaryTexture: offscreenTexture, destinationTexture: outputTexture)
        } else {
            copyTexture(from: offscreenTexture, to: outputTexture, commandBuffer: commandBuffer)
        }
    }
    
    nonisolated
    private func processGrayAdd(videoTexture: (any MTLTexture)?, offscreenTexture: MTLTexture, outputTexture: MTLTexture, commandBuffer: MTLCommandBuffer, device: MTLDevice) {
        let tempTextureDesc = createTempTextureDescriptor(from: offscreenTexture)
        
        guard let tempOffscreenTexture = device.makeTexture(descriptor: tempTextureDesc) else {
            print("Failed to create temporary offscreen texture")
            copyTexture(from: offscreenTexture, to: outputTexture, commandBuffer: commandBuffer)
            return
        }
        
        // Convert offscreen texture to binary image
        let offscreenThreshold = MPSImageThresholdBinary(device: device, thresholdValue: 0, maximumValue: 0.8, linearGrayColorTransform: nil)
        offscreenThreshold.encode(commandBuffer: commandBuffer, sourceTexture: offscreenTexture, destinationTexture: tempOffscreenTexture)
        
        if let videoTexture = videoTexture {
            guard let tempVideoTexture = device.makeTexture(descriptor: tempTextureDesc) else {
                print("Failed to create temporary video texture")
                copyTexture(from: tempOffscreenTexture, to: outputTexture, commandBuffer: commandBuffer)
                return
            }
            
            // Use very low threshold and linear grayscale conversion
//            let threshold = MPSImageThresholdToZero(device: device, thresholdValue: 0, linearGrayColorTransform: nil)
            let threshold = MPSImageThresholdBinary(device: device, thresholdValue: 0, maximumValue: 0.8, linearGrayColorTransform: nil)
            threshold.encode(commandBuffer: commandBuffer, sourceTexture: videoTexture, destinationTexture: tempVideoTexture)
            // Add two binary images
            let add = MPSImageAdd(device: device)
            add.encode(commandBuffer: commandBuffer, primaryTexture: tempVideoTexture, secondaryTexture: tempOffscreenTexture, destinationTexture: outputTexture)
        } else {
            copyTexture(from: tempOffscreenTexture, to: outputTexture, commandBuffer: commandBuffer)
        }
    }
    
    private func processGrayMixRed(videoTexture: (any MTLTexture)?, offscreenTexture: MTLTexture, outputTexture: MTLTexture, commandBuffer: MTLCommandBuffer, device: MTLDevice) {
        guard let videoTexture = videoTexture,
              let pipelineState = grayMixRedPipelineState else {
            // No video texture or pipeline state, fall back to copying offscreen texture
            copyTexture(from: offscreenTexture, to: outputTexture, commandBuffer: commandBuffer)
            return
        }
        
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            print("Failed to create compute encoder")
            copyTexture(from: offscreenTexture, to: outputTexture, commandBuffer: commandBuffer)
            return
        }
        
        computeEncoder.setComputePipelineState(pipelineState)
        computeEncoder.setTexture(videoTexture, index: 0)    // Video texture
        computeEncoder.setTexture(offscreenTexture, index: 1) // Offscreen texture
        computeEncoder.setTexture(outputTexture, index: 2)    // Output texture
        
        let threadgroupSize = MTLSize(width: 8, height: 8, depth: 1)
        let threadgroupCount = MTLSize(
            width: (outputTexture.width + threadgroupSize.width - 1) / threadgroupSize.width,
            height: (outputTexture.height + threadgroupSize.height - 1) / threadgroupSize.height,
            depth: 1
        )
        
        computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
        computeEncoder.endEncoding()
    }
    
    // MARK: - Helper Methods
    nonisolated
    private func createTempTextureDescriptor(from texture: MTLTexture) -> MTLTextureDescriptor {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: texture.pixelFormat,
            width: texture.width,
            height: texture.height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        return descriptor
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
