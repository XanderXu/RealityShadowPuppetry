//
//  HandEntityManager.swift
//  RealityShadowPuppetry
//
//  Created by 许M4 on 2025/9/4.
//

import RealityKit
import ARKit

final class HandEntityManager {
    private let wm = UnlitMaterial(color: .white)
    private lazy var colorsM: [UnlitMaterial] = {
        let rm = UnlitMaterial(color: .red)
        let gm = UnlitMaterial(color: .green)
        let bm = UnlitMaterial(color: .blue)
        let rnm = UnlitMaterial(color: .init(red: 0.5, green: 0, blue: 0, alpha: 1))
        let gnm = UnlitMaterial(color: .init(red: 0, green: 0.5, blue: 0, alpha: 1))
        let bnm = UnlitMaterial(color: .init(red: 0, green: 0, blue: 0.5, alpha: 1))
        return [bm, gm, bnm, gnm, rm, rnm]
    }()
    
    
    let rootEntity = Entity()
    
    var left: Entity?
    var right: Entity?
    
    func clean() {
        rootEntity.removeFromParent()
        rootEntity.children.removeAll()
        left = nil
        right = nil
    }
    public func setupHandModelEntity() async {
        let hand = try? await Entity(named: "HandBone")
//            hand?.printHierarchyDetails()
        let p = hand?.findFirstEntity(with: SkeletalPosesComponent.self)
        let bounds = p?.components[SkeletalPosesComponent.self]
        print(bounds?.poses.first?.jointNames)
        
    }
    @MainActor
    public func generateHandEntity(from handAnchor: HandAnchor, filter: CollisionFilter = .default) -> Entity {
        let hand = Entity()
        hand.name = handAnchor.chirality == .left ? "leftHand" : "rightHand"
        hand.transform.matrix = handAnchor.originFromAnchorTransform
        
        for positionInfo in handAnchor.handSkeleton?.allJoints ?? [] {
            let modelEntity = ModelEntity(mesh: .generateBox(width: 0.015, height: 0.015, depth: 0.015, splitFaces: true), materials: colorsM)//[+z, +y, -z, -y, +x, -x]
            modelEntity.transform.matrix = positionInfo.anchorFromJointTransform
            modelEntity.name = positionInfo.name.description + "-model"
            hand.addChild(modelEntity)
        }
        return hand
    }
    @MainActor
    public func updateHand(from handAnchor: HandAnchor, filter: CollisionFilter = .default) async {
        if handAnchor.chirality == .left {
            if left == nil {
                left = generateHandEntity(from: handAnchor, filter: filter)
                rootEntity.addChild(left!)
            } else {
                updateHandEntity(from: handAnchor, inEntiy: left!)
            }
            left?.isEnabled = handAnchor.isTracked
        } else {
            if right == nil {
                right = generateHandEntity(from: handAnchor, filter: filter)
                rootEntity.addChild(right!)
            } else {
                updateHandEntity(from: handAnchor, inEntiy: right!)
            }
            
            right?.isEnabled = handAnchor.isTracked
        }
    }
    private func updateHandEntity(from handAnchor: HandAnchor, inEntiy: Entity) {
        inEntiy.transform.matrix = handAnchor.originFromAnchorTransform
        for positionInfo in handAnchor.handSkeleton?.allJoints ?? [] {
            let modelEntity = inEntiy.findEntity(named: positionInfo.name.description + "-model")
            modelEntity?.transform.matrix = positionInfo.anchorFromJointTransform
        }
    }
    
    public func removeHand(from handAnchor: HandAnchor) {
        if handAnchor.chirality == .left {
            left?.removeFromParent()
            left = nil
        } else if handAnchor.chirality == .right { // Update right hand info.
            right?.removeFromParent()
            right = nil
        }
    }
    
    
    
    public var simHandOffset = simd_float3(0, 1.4, -0.2)
    
    @MainActor
    public func updateHand(from simHand: SimHand, filter: CollisionFilter = .default) async {
        let handVectors = simHand.convertToHandVector(offset: simHandOffset)
        if let leftHandVector = handVectors.left {
            if left == nil {
                left = generateHandRootEntity(from: leftHandVector, filter: filter)
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
                right = generateHandRootEntity(from: rightHandVector, filter: filter)
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
    private func generateHandRootEntity(from handVector: simd_float4x4, filter: CollisionFilter = .default) -> Entity {
        let modelEntity = ModelEntity(mesh: .generateBox(width: 0.15, height: 0.15, depth: 0.15, splitFaces: true), materials: colorsM)
        modelEntity.transform.matrix = handVector
        return modelEntity
    }
}
