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
    private var body: Entity?
    private var stationaryEntity: Entity?
    
    func clean() {
        rootEntity.children.removeAll()
        body = nil
    }
    
    public func loadBodyModelEntity() async throws {
        body = try await Entity(named: "BodyScene",in: realityKitContentBundle)
        stationaryEntity = body?.findFirstEntity(with: StationaryRobotRuntimeComponent.self)
        if let body {
            rootEntity.addChild(body)
        }
    }
    
    public func updateBodyModel(from handAnchor: HandAnchor, deviceMatrix: simd_float4x4?) {
        guard let stationaryEntity else { return }
        
        if handAnchor.chirality == .left {
            stationaryEntity.components[StationaryRobotRuntimeComponent.self]?.currentLeftHandPos = handAnchor.originFromAnchorTransform.translation
        } else if handAnchor.chirality == .right {
            stationaryEntity.components[StationaryRobotRuntimeComponent.self]?.currentRightHandPos = handAnchor.originFromAnchorTransform.translation
        }
        
        if let deviceMatrix {
            let lookAtPos = deviceMatrix.translation - deviceMatrix.zAxis * 0.2
            stationaryEntity.components[StationaryRobotRuntimeComponent.self]?.lookAtTarget = lookAtPos
        }
    }

    
    
    public func removeBody(from handAnchor: HandAnchor) {
        if handAnchor.chirality == .left {
            
        } else if handAnchor.chirality == .right { // Update right hand info.
            
        }
    }
    
}
