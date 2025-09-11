//
//  BodyShadowImmersiveView.swift
//  RealityShadowPuppetry
//
//  Created by 许M4 on 2025/6/18.
//

import SwiftUI
import RealityKit
import MetalKit

struct BodyShadowImmersiveView: View {
    @Environment(AppModel.self) private var model
    let device = MTLCreateSystemDefaultDevice()!
    var body: some View {
        RealityView { content in
            
            let entity = Entity()
            entity.name = "GameRoot"
            model.rootEntity = entity
            content.add(entity)
            

        }
        
        
    }
}

#Preview {
    BodyShadowImmersiveView()
}
