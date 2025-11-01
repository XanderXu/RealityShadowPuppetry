//
//  BodyShadowImmersiveView.swift
//  RealityShadowPuppetry
//
//  Created by 许 on 2025/6/18.
//

import SwiftUI
import RealityKit
import RealityKitContent
import AVFoundation

struct BodyShadowImmersiveView: View {
    @Environment(AppModel.self) private var model
    let asset = AVURLAsset(url: Bundle.main.url(forResource: "HDRMovie", withExtension: "mov")!)
    var body: some View {
        RealityView { content in
            StationaryRobotComponent.registerComponent()
            StationaryRobotSystem.registerSystem()
            
            
            let entity = Entity()
            entity.name = "GameRoot"
            model.rootEntity = entity
            content.add(entity)
            
            do {
                try await model.setup(asset: asset, trackingType: .body)
                guard let originalEntity = model.shadowMixManager?.originalVideoEntity, let shadowEntity = model.shadowMixManager?.mixedTextureEntity else {
                    return
                }
                entity.addChild(originalEntity)
                entity.addChild(shadowEntity)
                originalEntity.isEnabled = model.showOriginalVideo
                
                try await model.prepareBodyModel()
//                entity.addChild(model.shadowMixManager?.rootEntity ?? Entity())
                
            } catch {
                print(error)
            }
            
        }
        .upperLimbVisibility(.hidden)

        .task {
            await model.startHandAndDeviceTracking()
        }
        .task {
            await model.publishHandTrackingUpdates()
        }
        .task {
            await model.monitorSessionEvents()
        }
        
    }
}

#Preview {
    BodyShadowImmersiveView()
}
