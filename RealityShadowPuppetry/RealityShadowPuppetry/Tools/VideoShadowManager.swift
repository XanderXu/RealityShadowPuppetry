//
//  VideoShadowManager.swift
//  RealityShadowPuppetry
//
//  Created by 许M4 on 2025/9/2.
//

import RealityKit
import MetalKit
import AVFoundation
import MetalPerformanceShaders

@MainActor
final class VideoShadowManager {
    enum ShadowMixStyle: String, CaseIterable {
        case GrayShadow
        case ColorAdd
    }
    let mtlDevice = MTLCreateSystemDefaultDevice()!
    
    let originalEntity = ModelEntity()
    let shadowEntity = ModelEntity()
    var shadowStyle = ShadowMixStyle.GrayShadow
    
    
    
    private(set) var videoSize: CGSize?
    private(set) var player: AVPlayer?
    private(set) var offscreenRenderer: OffscreenRenderer?
    private var customCompositor: SampleCustomCompositor?
    
    
    // 播放状态监听相关属性
    var playerStatusDidChange: ((AVPlayer.TimeControlStatus) -> Void)?
    var playerItemStatusDidChange: ((AVPlayerItem.Status) -> Void)?
    var playbackDidFinish: (() -> Void)?
    
    private var timeControlStatusObserver: NSKeyValueObservation?
    private var playerItemStatusObserver: NSKeyValueObservation?
    private var playbackFinishedObserver: NSObjectProtocol?
    
    init(asset: AVAsset) async throws {
        
        let (player, size) = try await createPlayerAndSizeWithAsset(asset: asset)
        self.player = player
        self.videoSize = size
        self.customCompositor = player.currentItem?.customVideoCompositor as? SampleCustomCompositor
        
        setupPlayerObservers()


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
        
    }
    
    private func setupPlayerObservers() {
        guard let player = player else { return }
        
        // 监听播放控制状态变化 (playing, paused, waitingToPlayAtSpecifiedRate)
        timeControlStatusObserver = player.observe(\.timeControlStatus, options: [.new, .old]) { [weak self] player, change in
            DispatchQueue.main.async {
                self?.playerStatusDidChange?(player.timeControlStatus)
                print("Player status changed to: \(player.timeControlStatus)")
            }
        }
        
        // 监听播放项状态变化 (unknown, readyToPlay, failed)
        if let playerItem = player.currentItem {
            playerItemStatusObserver = playerItem.observe(\.status, options: [.new, .old]) { [weak self] playerItem, change in
                DispatchQueue.main.async {
                    self?.playerItemStatusDidChange?(playerItem.status)
                    print("PlayerItem status changed to: \(playerItem.status)")
                }
            }
        }
        
        // 监听播放完成通知
        playbackFinishedObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] notification in
            DispatchQueue.main.async {
                self?.playbackDidFinish?()
                print("Playback finished")
            }
        }
    }
    
    private func removePlayerObservers() {
        timeControlStatusObserver?.invalidate()
        timeControlStatusObserver = nil
        
        playerItemStatusObserver?.invalidate()
        playerItemStatusObserver = nil
        
        if let playbackFinishedObserver = playbackFinishedObserver {
            NotificationCenter.default.removeObserver(playbackFinishedObserver)
            self.playbackFinishedObserver = nil
        }
        
        // 清理闭包引用
        playerStatusDidChange = nil
        playerItemStatusDidChange = nil
        playbackDidFinish = nil
    }
    
    public func clean() {
        shadowStyle = .GrayShadow
        removePlayerObservers()
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
        
        if shadowStyle == .ColorAdd {
            if let videoTexture = videoTexture {
                // Create a MPS filter for color addition
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
        } else {
            // GrayShadow mode: 将两个纹理转换为黑白图像后相加
            // 创建临时纹理用于存储黑白处理结果
            let tempTextureDesc = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: offscreenTexture.pixelFormat,
                width: offscreenTexture.width,
                height: offscreenTexture.height,
                mipmapped: false
            )
            tempTextureDesc.usage = [.shaderRead, .shaderWrite]
            
            guard let tempOffscreenTexture = device.makeTexture(descriptor: tempTextureDesc) else {
                print("Failed to create temporary offscreen texture")
                // 回退方案：直接复制离屏纹理
                if let blitEncoder = commandBuffer.makeBlitCommandEncoder() {
                    blitEncoder.copy(from: offscreenTexture, to: outTexture)
                    blitEncoder.endEncoding()
                }
                return
            }
            
            // 先将离屏纹理转换为黑白图像
            let offscreenThreshold = MPSImageThresholdBinary(device: device, thresholdValue: 0.1, maximumValue: 0.6, linearGrayColorTransform: nil)
            offscreenThreshold.encode(commandBuffer: commandBuffer, sourceTexture: offscreenTexture, destinationTexture: tempOffscreenTexture)
            
            if let videoTexture = videoTexture {
                // 有视频纹理时：创建临时视频纹理并转换为黑白图像
                guard let tempVideoTexture = device.makeTexture(descriptor: tempTextureDesc) else {
                    print("Failed to create temporary video texture")
                    // 回退方案：直接复制已处理的离屏纹理
                    if let blitEncoder = commandBuffer.makeBlitCommandEncoder() {
                        blitEncoder.copy(from: tempOffscreenTexture, to: outTexture)
                        blitEncoder.endEncoding()
                    }
                    return
                }
                
                // 将视频纹理转换为黑白图像
                let videoThreshold = MPSImageThresholdBinary(device: device, thresholdValue: 0.1, maximumValue: 0.6, linearGrayColorTransform: nil)
                videoThreshold.encode(commandBuffer: commandBuffer, sourceTexture: videoTexture, destinationTexture: tempVideoTexture)
                
                // 将两个黑白图像相加
                let add = MPSImageAdd(device: device)
                add.encode(commandBuffer: commandBuffer, primaryTexture: tempVideoTexture, secondaryTexture: tempOffscreenTexture, destinationTexture: outTexture)
            } else {
                // 只有离屏纹理时：直接复制已处理的黑白离屏纹理
                if let blitEncoder = commandBuffer.makeBlitCommandEncoder() {
                    blitEncoder.copy(from: tempOffscreenTexture, to: outTexture)
                    blitEncoder.endEncoding()
                }
            }
        }
        
        // The usual Metal enqueue process.
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
}
