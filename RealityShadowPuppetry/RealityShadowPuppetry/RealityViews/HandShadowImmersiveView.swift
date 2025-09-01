//
//  HandShadowImmersiveView.swift
//  RealityShadowPuppetry
//
//  Created by 许M4 on 2025/6/18.
//

import SwiftUI
import RealityKit
import MetalKit
import AVFoundation

struct HandShadowImmersiveView: View {
    @Environment(AppModel.self) private var model
    let asset = AVURLAsset(url: Bundle.main.url(forResource: "HDRMovie", withExtension: "mov")!)
    let mtlDevice = MTLCreateSystemDefaultDevice()!
    
    var body: some View {
        RealityView { content in
            
            let entity = Entity()
            entity.name = "GameRoot"
            model.rootEntity = entity
            content.add(entity)
            
            do {
                // Get the actual video dimensions
                let videoTrack = try await asset.loadTracks(withMediaType: .video).first
                let naturalSize = try await videoTrack?.load(.naturalSize) ?? CGSize(width: 1920, height: 1080)

                // Create a descriptor for the LowLevelTexture with actual video dimensions
                
                // Create the LowLevelTexture and populate it on the GPU.
                let llt = try model.createLowLevelTexture(width: Int(naturalSize.width), height: Int(naturalSize.height))
                SampleCustomCompositor.mtlDevice = mtlDevice
                SampleCustomCompositor.llt = llt
                SampleCustomCompositor.blurRadius = 8
                
                // Create a video composition with CustomCompositor
                let composition = try await AVMutableVideoComposition.videoComposition(withPropertiesOf: asset)
                composition.customVideoCompositorClass = SampleCustomCompositor.self
                let playerItem = AVPlayerItem(asset: asset)
                playerItem.videoComposition = composition
                
                let player = AVPlayer(playerItem: playerItem)
                let videoMaterial = VideoMaterial(avPlayer: player)
                // Return an entity of a plane which uses the VideoMaterial.
                let modelEntity = ModelEntity(mesh: .generatePlane(width: 1, height: 1), materials: [videoMaterial])
                entity.addChild(modelEntity)
                modelEntity.position = SIMD3(x: 0, y: 1, z: -2)
                player.play()
                
                // Create a TextureResource from the LowLevelTexture.
                let resource = try await TextureResource(from: llt)
                // Create a material that uses the texture.
                let material = UnlitMaterial(texture: resource)

                // Return an entity of a plane which uses the generated texture.
                let modelEntity2 = ModelEntity(mesh: .generatePlane(width: 1, height: 1), materials: [material])
                entity.addChild(modelEntity2)
                modelEntity2.position = SIMD3(x: 1.2, y: 1, z: -2)
                
            } catch {
                print(error)
            }

        }
        .onChange(of: model.shadowStyle) { oldValue, newValue in
            
            SampleCustomCompositor.blurRadius = 28
        }
        
        
    }
    
    
    
}

#Preview {
    HandShadowImmersiveView()
}
