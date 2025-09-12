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
            
//            let hand = try? await Entity(named: "Low-Poly_Hand_With_Animation")
//            hand?.printHierarchy()
//            hand?.printChildrenInfo()
//            let p = hand?.findEntity(named: "skin0")
//            let pose = p?.components[SkeletalPosesComponent.self]
//            pose?.poses.forEach { sp in
//                print(sp.id,sp.jointNames)
//            }
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
//        .onChange(of: model.shadowStyle) { oldValue, newValue in
//            model.videoShadowManager?.shadowStyle = newValue
//        }
//        .onChange(of: model.showOriginalVideo) { oldValue, newValue in
//            let videoEntity = model.videoShadowManager?.originalEntity
//            videoEntity?.isEnabled = newValue
//        }
        
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
