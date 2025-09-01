//
//  AppModel.swift
//  RealityShadowPuppetry
//
//  Created by 许M4 on 2025/6/16.
//

import SwiftUI
import RealityKit
import MetalKit
import AVFoundation

/// Maintains app-wide state
@MainActor
@Observable
class AppModel {
    enum ShadowStyle: String, CaseIterable {
        case Gray
        case Color
    }
    var rootEntity: Entity?
    var turnOnImmersiveSpace = false
    var shadowStyle = ShadowStyle.Gray
    var showVideo = false
    
    private let mtlDevice = MTLCreateSystemDefaultDevice()!
    
    func clear() {
        rootEntity?.children.removeAll()
        
    }
    
    /// Resets game state information.
    func reset() {
        debugPrint(#function)
        
        shadowStyle = ShadowStyle.Gray
        clear()
    }
    func createPlayerAndLowLevelTextureWithAsset(asset: AVAsset) async throws -> (AVPlayer, LowLevelTexture) {
        // Create a video composition with CustomCompositor
        let composition = try await AVMutableVideoComposition.videoComposition(withPropertiesOf: asset)
        composition.customVideoCompositorClass = SampleCustomCompositor.self
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.videoComposition = composition
        let player = AVPlayer(playerItem: playerItem)
        
        let videoTrack = try await asset.loadTracks(withMediaType: .video).first!
        let naturalSize = try await videoTrack.load(.naturalSize)
        
        let textureDescriptor = createTextureDescriptor(width: Int(naturalSize.width), height: Int(naturalSize.height))
        let llt = try LowLevelTexture(descriptor: textureDescriptor)
        
        return (player, llt)
    }
    func setupCustomCompositor(inTexture: any MTLTexture, llt: LowLevelTexture) {
        SampleCustomCompositor.mtlDevice = mtlDevice
        SampleCustomCompositor.llt = llt
        SampleCustomCompositor.inTexture = inTexture
    }
    func createMTLTexture(name: String, bundle: Bundle? = nil) throws -> any MTLTexture {
        let textureLoader = MTKTextureLoader(device: mtlDevice)
        let inTexture = try textureLoader.newTexture(name: name, scaleFactor: 1, bundle: bundle)
        return inTexture
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
        desc.textureUsage = [.shaderRead, .shaderWrite]
        desc.swizzle = .init(red: .red, green: .green, blue: .blue, alpha: .alpha)

        return desc
    }
}



/// A description of the modules that the app can present.
enum Module: String, Identifiable, CaseIterable, Equatable {
    case handShadow
    case bodyShadow
    
    var id: Self { self }
    var name: LocalizedStringKey {
        LocalizedStringKey(rawValue)
    }

    var immersiveId: String {
        self.rawValue + "ID"
    }

}
