//
//  VideoShadowCenter.swift
//  RealityShadowPuppetry
//
//  Created by 许M4 on 2025/9/2.
//

import RealityKit
import MetalKit
import AVFoundation
import MetalPerformanceShaders

@MainActor
final class VideoShadowCenter {
    let mtlDevice = MTLCreateSystemDefaultDevice()!
    
    let originalEntity = ModelEntity()
    let shadowEntity = ModelEntity()
    private(set) var videoSize: CGSize?
    private(set) var player: AVPlayer?
    private(set) var offscreenRenderer: OffscreenRenderer?
    private var customCompositor: SampleCustomCompositor?
    
    init(asset: AVAsset) async throws {
        
        let (player, size) = try await createPlayerAndSizeWithAsset(asset: asset)
        self.player = player
        self.videoSize = size
        self.customCompositor = player.currentItem?.customVideoCompositor as? SampleCustomCompositor
        
        let videoMaterial = VideoMaterial(avPlayer: player)
        // Return an entity of a plane which uses the VideoMaterial.
        originalEntity.model = .init(mesh: .generatePlane(width: 1, height: Float(size.height/size.width)), materials: [videoMaterial])
        originalEntity.name = "OriginalVideo"
        originalEntity.position = SIMD3(x: 0, y: 1, z: -2)
        
        let textureDescriptor = createTextureDescriptor(width: Int(size.width), height: Int(size.height))
        let llt = try LowLevelTexture(descriptor: textureDescriptor)
        // Create a TextureResource from the LowLevelTexture.
        let resource = try await TextureResource(from: llt)
        // Create a material that uses the texture.
        let material = UnlitMaterial(texture: resource)
        shadowEntity.model = .init(mesh: .generatePlane(width: 1, height: Float(size.height/size.width)), materials: [material])
        shadowEntity.name = "MixedTexture"
        shadowEntity.position = SIMD3(x: 1.2, y: 1, z: -2)
        
        
        offscreenRenderer = try OffscreenRenderer(device: mtlDevice, textureSize: size)
        offscreenRenderer?.rendererUpdate = { [weak self, weak customCompositor] in
            if player.timeControlStatus != .playing {
                self?.populateMPS(videoTexture: customCompositor?.lastestPixel, offscreenTexture: self?.offscreenRenderer?.colorTexture, lowLevelTexture: llt, device: self?.mtlDevice)
            }
        }
        
        customCompositor?.videoPixelUpdate = { [weak self, weak customCompositor] in
            self?.populateMPS(videoTexture: customCompositor?.lastestPixel, offscreenTexture: self?.offscreenRenderer?.colorTexture, lowLevelTexture: llt, device: self?.mtlDevice)
        }
 
        
        player.play()

    }
    
    
    public func clean() {
        originalEntity.removeFromParent()
        shadowEntity.removeFromParent()
        offscreenRenderer?.removeAllEntities()
        offscreenRenderer?.rendererUpdate = nil
        player?.pause()
        customCompositor?.cancelAllPendingVideoCompositionRequests()
        customCompositor?.lastestPixel = nil
        customCompositor?.videoPixelUpdate = nil
    }
    
    
    
    private func createPlayerAndSizeWithAsset(asset: AVAsset) async throws -> (AVPlayer, CGSize) {
        // Create a video composition with CustomCompositor
        let composition = try await AVMutableVideoComposition.videoComposition(withPropertiesOf: asset)
        composition.customVideoCompositorClass = SampleCustomCompositor.self
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.videoComposition = composition
        let player = AVPlayer(playerItem: playerItem)
        
        let videoTrack = try await asset.loadTracks(withMediaType: .video).first!
        let naturalSize = try await videoTrack.load(.naturalSize)
        
        return (player, naturalSize)
    }
    
    

    private func createTextureDescriptor(width: Int, height: Int) -> LowLevelTexture.Descriptor {
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
    
    
    @MainActor
    func populateMPS(videoTexture: (any MTLTexture)?, offscreenTexture: (any MTLTexture)?, lowLevelTexture: LowLevelTexture?, device: MTLDevice?) {
        
        guard let lowLevelTexture = lowLevelTexture, let device = device, let offscreenTexture = offscreenTexture else { return }
        
        // Set up the Metal command queue and compute command encoder,
        // or abort if that fails.
        guard let commandQueue = device.makeCommandQueue(),
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }
        let outTexture = lowLevelTexture.replace(using: commandBuffer)
        if let videoTexture = videoTexture {
            // Create a MPS filter with dynamic blur radius
            let add = MPSImageAdd(device: device)
            // set input output
            add.encode(commandBuffer: commandBuffer, primaryTexture: videoTexture, secondaryTexture: offscreenTexture, destinationTexture: outTexture)
        } else {
            // 创建一个blit编码器将结果复制到RealityKit纹理
            if let blitEncoder = commandBuffer.makeBlitCommandEncoder() {
                blitEncoder.copy(from: offscreenTexture, to: outTexture)
                blitEncoder.endEncoding()
            }
        }
        // The usual Metal enqueue process.
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
}
