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
        case ColorAdd
        case GrayAdd
        case GrayMixRed
    }
    let mtlDevice = MTLCreateSystemDefaultDevice()!
    
    let originalEntity = ModelEntity()
    let shadowEntity = ModelEntity()
    var shadowStyle = ShadowMixStyle.GrayAdd
    
    // MARK: - Initialization
    var playerStatusDidChange: ((AVPlayer.TimeControlStatus) -> Void)?
    var playerItemStatusDidChange: ((AVPlayerItem.Status) -> Void)?
    var playbackDidFinish: (() -> Void)?
    
    
    private(set) var videoSize: CGSize?
    private(set) var player: AVPlayer?
    private(set) var offscreenRenderer: OffscreenRenderer?
    // MARK: - Private Properties
    private var customCompositor: SampleCustomCompositor?
    private var grayMixRedPipelineState: MTLComputePipelineState?
    private var timeControlStatusObserver: NSKeyValueObservation?
    private var playerItemStatusObserver: NSKeyValueObservation?
    private var playbackFinishedObserver: NSObjectProtocol?
    
    init(asset: AVAsset) async throws {
        // 初始化计算管线状态
        grayMixRedPipelineState = Self.createGrayMixRedComputePipelineState(device: mtlDevice)
        
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
        var material = UnlitMaterial(texture: resource)
        material.opacityThreshold = 0.01
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
    
    // MARK: - Metal Shader Setup
    
    /// 创建灰度混合红色通道的计算管线状态
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
    
    @MainActor
    func populateMPS(videoTexture: (any MTLTexture)?, offscreenTexture: (any MTLTexture)?, lowLevelTexture: LowLevelTexture?, device: MTLDevice?) {
        
        guard let lowLevelTexture = lowLevelTexture, 
              let device = device, 
              let offscreenTexture = offscreenTexture else { return }
        
        guard let commandQueue = device.makeCommandQueue(),
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            print("Failed to create command queue or command buffer")
            return
        }
        
        let outTexture = lowLevelTexture.replace(using: commandBuffer)
        
        switch shadowStyle {
        case .ColorAdd:
            processColorAdd(videoTexture: videoTexture, offscreenTexture: offscreenTexture, outputTexture: outTexture, commandBuffer: commandBuffer, device: device)
            
        case .GrayAdd:
            processGrayAdd(videoTexture: videoTexture, offscreenTexture: offscreenTexture, outputTexture: outTexture, commandBuffer: commandBuffer, device: device)
            
        case .GrayMixRed:
            processGrayMixRed(videoTexture: videoTexture, offscreenTexture: offscreenTexture, outputTexture: outTexture, commandBuffer: commandBuffer, device: device)
        }
        
        // Commit and wait for completion
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    // MARK: - Processing Methods
    
    /// 处理颜色相加模式
    private func processColorAdd(videoTexture: (any MTLTexture)?, offscreenTexture: MTLTexture, outputTexture: MTLTexture, commandBuffer: MTLCommandBuffer, device: MTLDevice) {
        if let videoTexture = videoTexture {
            let add = MPSImageAdd(device: device)
            add.encode(commandBuffer: commandBuffer, primaryTexture: videoTexture, secondaryTexture: offscreenTexture, destinationTexture: outputTexture)
        } else {
            copyTexture(from: offscreenTexture, to: outputTexture, commandBuffer: commandBuffer)
        }
    }
    
    /// 处理灰度相加模式
    private func processGrayAdd(videoTexture: (any MTLTexture)?, offscreenTexture: MTLTexture, outputTexture: MTLTexture, commandBuffer: MTLCommandBuffer, device: MTLDevice) {
        let tempTextureDesc = createTempTextureDescriptor(from: offscreenTexture)
        
        guard let tempOffscreenTexture = device.makeTexture(descriptor: tempTextureDesc) else {
            print("Failed to create temporary offscreen texture")
            copyTexture(from: offscreenTexture, to: outputTexture, commandBuffer: commandBuffer)
            return
        }
        
        // 将离屏纹理转换为二值化图像
        let offscreenThreshold = MPSImageThresholdBinary(device: device, thresholdValue: 0, maximumValue: 0.8, linearGrayColorTransform: nil)
        offscreenThreshold.encode(commandBuffer: commandBuffer, sourceTexture: offscreenTexture, destinationTexture: tempOffscreenTexture)
        
        if let videoTexture = videoTexture {
            guard let tempVideoTexture = device.makeTexture(descriptor: tempTextureDesc) else {
                print("Failed to create temporary video texture")
                copyTexture(from: tempOffscreenTexture, to: outputTexture, commandBuffer: commandBuffer)
                return
            }
            
            
            // 使用非常低的阈值和线性灰度转换
            let threshold = MPSImageThresholdToZero(device: device, thresholdValue: 0, linearGrayColorTransform: nil)
            threshold.encode(commandBuffer: commandBuffer, sourceTexture: videoTexture, destinationTexture: tempVideoTexture)
            // 将两个二值化图像相加
            let add = MPSImageAdd(device: device)
            add.encode(commandBuffer: commandBuffer, primaryTexture: tempVideoTexture, secondaryTexture: tempOffscreenTexture, destinationTexture: outputTexture)
        } else {
            copyTexture(from: tempOffscreenTexture, to: outputTexture, commandBuffer: commandBuffer)
        }
    }
    
    /// 处理灰度混合红色通道模式
    private func processGrayMixRed(videoTexture: (any MTLTexture)?, offscreenTexture: MTLTexture, outputTexture: MTLTexture, commandBuffer: MTLCommandBuffer, device: MTLDevice) {
        guard let videoTexture = videoTexture,
              let pipelineState = grayMixRedPipelineState else {
            // 没有视频纹理或管线状态，回退到复制离屏纹理
            copyTexture(from: offscreenTexture, to: outputTexture, commandBuffer: commandBuffer)
            return
        }
        
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            print("Failed to create compute encoder")
            copyTexture(from: offscreenTexture, to: outputTexture, commandBuffer: commandBuffer)
            return
        }
        
        computeEncoder.setComputePipelineState(pipelineState)
        computeEncoder.setTexture(videoTexture, index: 0)    // 视频纹理
        computeEncoder.setTexture(offscreenTexture, index: 1) // 离屏纹理
        computeEncoder.setTexture(outputTexture, index: 2)    // 输出纹理
        
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
    
    /// 创建临时纹理描述符
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
    
    /// 复制纹理的辅助方法
    private func copyTexture(from sourceTexture: MTLTexture, to destinationTexture: MTLTexture, commandBuffer: MTLCommandBuffer) {
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            print("Failed to create blit encoder")
            return
        }
        blitEncoder.copy(from: sourceTexture, to: destinationTexture)
        blitEncoder.endEncoding()
    }
}
