//
//  HandCenter.swift
//  RealityShadowPuppetry
//
//  Created by 许M4 on 2025/9/4.
//

import RealityKit
import ARKit

final class HandCenter {
    let rootEntity = Entity()
    
    var left: Entity?
    var right: Entity?
    
    func clean() {
        rootEntity.removeFromParent()
        rootEntity.children.removeAll()
        left = nil
        right = nil
    }
    
    @MainActor
    public func updateHand(from simHand: SimHand, filter: CollisionFilter = .default) async {
        let handVectors = simHand.convertToHandVector(offset: .init(0, 0.2, -0.2))
        if let leftHandVector = handVectors.left {
            if left == nil {
                left = generateHandEntity(from: leftHandVector, filter: filter)
                left?.name = "leftHand"
                rootEntity.addChild(left!)
            } else {
                left?.isEnabled = true
                left?.transform.matrix = leftHandVector
            }
        } else {
            left?.isEnabled = false
        }
        
        if let rightHandVector = handVectors.right {
            if right == nil {
                right = generateHandEntity(from: rightHandVector, filter: filter)
                right?.name = "rightHand"
                rootEntity.addChild(right!)
            } else {
                right?.isEnabled = true
                right?.transform.matrix = rightHandVector
            }
        } else {
            right?.isEnabled = false
        }
    }
    
    @MainActor
    private func generateHandEntity(from handVector: simd_float4x4, filter: CollisionFilter = .default) -> Entity {
        
        let rm = UnlitMaterial(color: .red)
        let gm = UnlitMaterial(color: .green)
        let bm = UnlitMaterial(color: .blue)
        let rnm = UnlitMaterial(color: .init(red: 0.5, green: 0, blue: 0, alpha: 1))
        let gnm = UnlitMaterial(color: .init(red: 0, green: 0.5, blue: 0, alpha: 1))
        let bnm = UnlitMaterial(color: .init(red: 0, green: 0, blue: 0.5, alpha: 1))
        
        let modelEntity = ModelEntity(mesh: .generateBox(width: 0.15, height: 0.15, depth: 0.15, splitFaces: true), materials: [bm, gm, bnm, gnm, rm, rnm])
        modelEntity.transform.matrix = handVector
        return modelEntity
    }
}
