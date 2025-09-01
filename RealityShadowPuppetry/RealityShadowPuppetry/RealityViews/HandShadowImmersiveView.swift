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
import MetalPerformanceShaders

struct HandShadowImmersiveView: View {
    @Environment(AppModel.self) private var model
    let asset = AVURLAsset(url: Bundle.main.url(forResource: "HDRMovie", withExtension: "mov")!)
    
    var body: some View {
        RealityView { content in
            
            let entity = Entity()
            entity.name = "GameRoot"
            model.rootEntity = entity
            content.add(entity)
            do {
                let inTexture = try model.createMTLTexture(name: "Shop_L", bundle: nil)
                let (player, llt) = try await model.createPlayerAndLowLevelTextureWithAsset(asset: asset)
                
                let videoMaterial = VideoMaterial(avPlayer: player)
                // Return an entity of a plane which uses the VideoMaterial.
                let modelEntity = ModelEntity(mesh: .generatePlane(width: 1, height: 1), materials: [videoMaterial])
                entity.addChild(modelEntity)
                modelEntity.name = "OriginalVideo"
                modelEntity.position = SIMD3(x: 0, y: 1, z: -2)
                modelEntity.isEnabled = model.showVideo
                
                
                model.setupCustomCompositor(inTexture: inTexture, llt: llt)
                // Create a TextureResource from the LowLevelTexture.
                let resource = try await TextureResource(from: llt)
                // Create a material that uses the texture.
                let material = UnlitMaterial(texture: resource)
                // Return an entity of a plane which uses the generated texture.
                let modelEntity2 = ModelEntity(mesh: .generatePlane(width: 1, height: 1), materials: [material])
                entity.addChild(modelEntity2)
                modelEntity2.name = "GeneratedTexture"
                modelEntity2.position = SIMD3(x: 1.2, y: 1, z: -2)
                
                
                player.play()
                
                
                let box = ModelEntity(mesh: MeshResource.generateBox(size: 0.1), materials: [UnlitMaterial(color: .green)])
                box.name = "Box"
                box.position = SIMD3(x: 0, y: 0, z: -2)
                let off = try OffscreenRenderModel(scene: box, device: model.mtlDevice, textureSize: SIMD2(3840, 2160))
                try off.render()
                SampleCustomCompositor.inTexture = off.colorTexture
                

            } catch {
                print(error)
            }
            
        }
        .onChange(of: model.shadowStyle) { oldValue, newValue in
            
        }
        .onChange(of: model.showVideo) { oldValue, newValue in
            let videoEntity = model.rootEntity?.findEntity(named: "OriginalVideo")
            videoEntity?.isEnabled = newValue
        }
        
    }
    
    
    
}

#Preview {
    HandShadowImmersiveView()
}
