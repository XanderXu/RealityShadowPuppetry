//
//  StereoImageImmersiveView.swift
//  RealityShadowPuppetry
//
//  Created by 许 on 2025/11/20.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct StereoImageImmersiveView: View {
    @Environment(AppModel.self) private var model
    
    var body: some View {
        RealityView { content in
            
            let entity = Entity()
            entity.name = "GameRoot"
            model.rootEntity = entity
            content.add(entity)
            
            do {
                try await model.setupStereoImageManager()
                guard let stereoEntity = model.stereoImageManager?.mixedTextureEntity else {
                    return
                }
                entity.addChild(stereoEntity)
                
                try await model.prepareStereoModel()
                //For test
//                entity.addChild(model.shadowMixManager?.rootEntity ?? Entity())
                
            } catch {
                print(error)
            }
            
        }

        
        
    }
}

#Preview {
    StereoImageImmersiveView()
}
