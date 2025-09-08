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
            let hand = try? await Entity(named: "Max-walk")
//            hand?.printHierarchy()
//            hand?.printChildrenInfo()
            let p = hand?.findEntity(named: "max_root")
            let pose = p?.components[SkeletalPosesComponent.self]
            pose?.poses.forEach { sp in
                print(sp.id,sp.jointNames)
            }
            do {
                try await model.setup(asset: asset)
                guard let originalEntity = model.videoShadowCenter?.originalEntity, let shadowEntity = model.videoShadowCenter?.shadowEntity else {
                    return
                }
                entity.addChild(originalEntity)
                entity.addChild(shadowEntity)
                originalEntity.isEnabled = model.showVideo
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
