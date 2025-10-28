//
//  BodyEntityManager.swift
//  RealityShadowPuppetry
//
//  Created by 许M4 on 2025/10/28.
//

import RealityKit
import ARKit
import RealityKitContent

final class BodyEntityManager {
    
    
    let rootEntity = Entity()
    private var left: Entity?
    private var right: Entity?
    private var leftModel: Entity?
    private var rightModel: Entity?
    
    
    func clean() {
        rootEntity.children.removeAll()
        left = nil
        right = nil
    }
    
    public func loadBodyModelEntity() async throws {
        left = try await Entity(named: "BodyScene",in: realityKitContentBundle)
        leftModel = left?.findFirstEntity(with: SkeletalPosesComponent.self)
        
        if let left {
            rootEntity.addChild(left)
        }
    }
    
    public func updateBodyModel(from handAnchor: HandAnchor) async {
        if handAnchor.chirality == .left {
            
            
        }
    }

    
    
    public func removeBody(from handAnchor: HandAnchor) {
        if handAnchor.chirality == .left {
            
        } else if handAnchor.chirality == .right { // Update right hand info.
            
        }
    }
    
}
