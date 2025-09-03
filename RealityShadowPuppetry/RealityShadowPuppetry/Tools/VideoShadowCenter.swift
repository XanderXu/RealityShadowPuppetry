//
//  VideoShadowCenter.swift
//  RealityShadowPuppetry
//
//  Created by 许M4 on 2025/9/2.
//

import RealityKit
import MetalKit
import AVFoundation


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
        customCompositor?.mtlDevice = mtlDevice
        customCompositor?.llt = llt
        customCompositor?.inTexture = offscreenRenderer?.colorTexture
        
        
        player.play()
//        
//        let box = ModelEntity(mesh: MeshResource.generateBox(size: 0.1), materials: [UnlitMaterial(color: .green)])
//        box.name = "Box"
//        box.position = SIMD3(x: 0, y: 0, z: -2)
//        offscreenRenderer?.addEntity(box)
//        try offscreenRenderer?.render()
    }
    
    
    public func clean() {
        originalEntity.removeFromParent()
        shadowEntity.removeFromParent()
        offscreenRenderer?.removeAllEntities()
        player?.pause()
        customCompositor?.cancelAllPendingVideoCompositionRequests()
        customCompositor?.mtlDevice = nil
        customCompositor?.llt = nil
        customCompositor?.inTexture = nil
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
}
