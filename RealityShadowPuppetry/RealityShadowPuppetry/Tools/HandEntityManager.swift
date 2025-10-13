//
//  HandEntityManager.swift
//  RealityShadowPuppetry
//
//  Created by 许M4 on 2025/9/4.
//

import RealityKit
import ARKit
import RealityKitContent

@MainActor
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
    private var leftModel: Entity?
    private var rightModel: Entity?
    
    
    let rootEntity = Entity()
    
    var left: Entity?
    var right: Entity?
    
    
    func clean() {
        rootEntity.removeFromParent()
        rootEntity.children.removeAll()
        left = nil
        right = nil
    }
    
    public func loadHandModelEntity() async throws {
        left = try await Entity(named: "HandBone",in: realityKitContentBundle)
        leftModel = left?.findFirstEntity(with: SkeletalPosesComponent.self)
        //        print(poses?.poses.first?.id, poses?.poses.first?.jointNames, poses?.poses.first?.jointTransforms)
                /*
                 "/root/scene/skin0/skeleton/skeleton",
                ["n9", "n9/n10", "n9/n10/n11",
                 "n9/n10/n11/n12", "n9/n10/n11/n12/n13", "n9/n10/n11/n12/n13/n14", "n9/n10/n11/n12/n13/n14/n15",
                 "n9/n10/n11/n16", "n9/n10/n11/n16/n17", "n9/n10/n11/n16/n17/n18", "n9/n10/n11/n16/n17/n18/n19",
                 "n9/n10/n11/n20", "n9/n10/n11/n20/n21", "n9/n10/n11/n20/n21/n22", "n9/n10/n11/n20/n21/n22/n23",
                 "n9/n10/n11/n24", "n9/n10/n11/n24/n25", "n9/n10/n11/n24/n25/n26", "n9/n10/n11/n24/n25/n26/n27",
                 "n9/n10/n28", "n9/n10/n28/n29", "n9/n10/n28/n29/n30"]
                 */
        left?.position = simd_float3(0, 0.8, -1)
        left?.scale = simd_float3(0.002, 0.002, 0.002)
        if let left {
            rootEntity.addChild(left)
        }
    }
    
    public func updateHandModel(from handAnchor: HandAnchor) {
        if handAnchor.chirality == .left {
            left?.transform.matrix = handAnchor.originFromAnchorTransform
            var poses = leftModel?.components[SkeletalPosesComponent.self]
    
            if let handSkeleton = handAnchor.handSkeleton {
                poses?.poses.set(.init(id: "/root/scene/skin0/skeleton/skeleton", joints: [
                    ("n9", Transform(matrix: handSkeleton.joint(.wrist).parentFromJointTransform)),
//                    ("n9/n10", Transform(matrix: handSkeleton.joint(.thumbKnuckle).parentFromJointTransform)),
                    ("n9/n10/n28", Transform(matrix: handSkeleton.joint(.thumbIntermediateBase).parentFromJointTransform)),
                    ("n9/n10/n28/n29", Transform(matrix: handSkeleton.joint(.thumbIntermediateTip).parentFromJointTransform)),
                    ("n9/n10/n28/n29/n30", Transform(matrix: handSkeleton.joint(.thumbTip).parentFromJointTransform)),
                    
                    
                    ("n9/n10/n11", Transform(matrix: handSkeleton.joint(.indexFingerKnuckle).parentFromJointTransform)),
                    ("n9/n10/n11/n12", Transform(matrix: handSkeleton.joint(.indexFingerIntermediateBase).parentFromJointTransform)),
                    ("n9/n10/n11/n12/n13", Transform(matrix: handSkeleton.joint(.indexFingerIntermediateTip).parentFromJointTransform)),
                    ("n9/n10/n11/n12/n13/n14", Transform(matrix: handSkeleton.joint(.indexFingerTip).parentFromJointTransform)),
                    
                ]))
            }
        }
    }

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
    
    private func generateHandRootEntity(from handVector: simd_float4x4, filter: CollisionFilter = .default) -> Entity {
        let modelEntity = ModelEntity(mesh: .generateBox(width: 0.15, height: 0.15, depth: 0.15, splitFaces: true), materials: colorsM)
        modelEntity.transform.matrix = handVector
        return modelEntity
    }
}
