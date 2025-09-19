//
//  HandShadowImmersiveView.swift
//  RealityShadowPuppetry
//
//  Created by 许M4 on 2025/6/18.
//

import SwiftUI
import RealityKit
import AVFoundation

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
                try await model.setup(asset: asset)
                guard let originalEntity = model.videoShadowManager?.originalEntity, let shadowEntity = model.videoShadowManager?.shadowEntity else {
                    return
                }
                entity.addChild(originalEntity)
                entity.addChild(shadowEntity)
                originalEntity.isEnabled = model.showOriginalVideo
                
            } catch {
                print(error)
            }
            
        }
        .upperLimbVisibility(.hidden)

        .task {
            await model.startHandTracking()
        }
        .task {
            await model.publishHandTrackingUpdates()
        }
        .task {
            await model.monitorSessionEvents()
        }
#if targetEnvironment(simulator)
        .task {
            await model.publishSimHandTrackingUpdates()
        }
#endif
        
    }
    
    
    
}

#Preview {
    HandShadowImmersiveView()
}
