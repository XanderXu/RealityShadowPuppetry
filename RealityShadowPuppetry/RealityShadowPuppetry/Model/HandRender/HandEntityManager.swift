//
//  HandEntityManager.swift
//  RealityShadowPuppetry
//
//  Created by 许 on 2025/9/4.
//

import RealityKit
import ARKit
import RealityKitContent

final class HandEntityManager {
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
    private var left: Entity?
    private var right: Entity?
    private var leftModel: Entity?
    private var rightModel: Entity?
    
    
    func clean() {
        rootEntity.children.removeAll()
        leftModel = nil
        left = nil
        rightModel = nil
        right = nil
    }
    
    public func loadHandModelEntity() async throws {
        left = try await Entity(named: "LeftHand",in: realityKitContentBundle)
        leftModel = left?.findFirstEntity(with: SkeletalPosesComponent.self)
        right = try await Entity(named: "RightHand",in: realityKitContentBundle)
        rightModel = right?.findFirstEntity(with: SkeletalPosesComponent.self)
        
        if let left {
            rootEntity.addChild(left)
        }
        if let right {
            rootEntity.addChild(right)
        }
//        if let  poses = leftModel?.components[SkeletalPosesComponent.self] {
//            print(poses.poses.default?.id ?? "", poses.poses.default?.jointNames ?? "")
//        }
        
        /*
         Optional("/root/Armature/Armature")
         Optional(["Wrist", "Wrist/ThumbKnuckle", "Wrist/ThumbKnuckle/ThumbIntermediateBase", "Wrist/ThumbKnuckle/ThumbIntermediateBase/ThumbIntermediateTip", "Wrist/ThumbKnuckle/ThumbIntermediateBase/ThumbIntermediateTip/ThumbTip",
         "Wrist/IndexFingerMetacarpal", "Wrist/IndexFingerMetacarpal/IndexFingerKnuckle", "Wrist/IndexFingerMetacarpal/IndexFingerKnuckle/IndexFingerIntermediateBase", "Wrist/IndexFingerMetacarpal/IndexFingerKnuckle/IndexFingerIntermediateBase/IndexFingerIntermediateTip", "Wrist/IndexFingerMetacarpal/IndexFingerKnuckle/IndexFingerIntermediateBase/IndexFingerIntermediateTip/IndexFingerTip",
         "Wrist/MiddleFingerMetacarpal", "Wrist/MiddleFingerMetacarpal/MiddleFingerKnuckle", "Wrist/MiddleFingerMetacarpal/MiddleFingerKnuckle/MiddleFingerIntermediateBase", "Wrist/MiddleFingerMetacarpal/MiddleFingerKnuckle/MiddleFingerIntermediateBase/MiddleFingerIntermediateTip", "Wrist/MiddleFingerMetacarpal/MiddleFingerKnuckle/MiddleFingerIntermediateBase/MiddleFingerIntermediateTip/MiddleFingerTip",
         "Wrist/RingFingerMetacarpal", "Wrist/RingFingerMetacarpal/RingFingerKnuckle", "Wrist/RingFingerMetacarpal/RingFingerKnuckle/RingFingerIntermediateBase", "Wrist/RingFingerMetacarpal/RingFingerKnuckle/RingFingerIntermediateBase/RingFingerIntermediateTip", "Wrist/RingFingerMetacarpal/RingFingerKnuckle/RingFingerIntermediateBase/RingFingerIntermediateTip/RingFingerTip",
         "Wrist/LittleFingerMetacarpal", "Wrist/LittleFingerMetacarpal/LittleFingerKnuckle", "Wrist/LittleFingerMetacarpal/LittleFingerKnuckle/LittleFingerIntermediateBase", "Wrist/LittleFingerMetacarpal/LittleFingerKnuckle/LittleFingerIntermediateBase/LittleFingerIntermediateTip", "Wrist/LittleFingerMetacarpal/LittleFingerKnuckle/LittleFingerIntermediateBase/LittleFingerIntermediateTip/LittleFingerTip"])
         */
        
    }
    
    public func updateHandModel(from handAnchor: HandAnchor) {
        var targetEntity: Entity?
        var targetModel: Entity?
        if handAnchor.chirality == .left {
            targetEntity = left
            targetModel = leftModel
        } else if handAnchor.chirality == .right {
            targetEntity = right
            targetModel = rightModel
        }
        targetEntity?.transform.matrix = handAnchor.originFromAnchorTransform
        if let handSkeleton = handAnchor.handSkeleton {
            let skeletalPose: SkeletalPose = .init(id: "/root/Armature/Armature", joints: [
                ("Wrist/ThumbKnuckle", Transform(matrix:  handSkeleton.joint(.thumbKnuckle).parentFromJointTransform)),
                ("Wrist/ThumbKnuckle/ThumbIntermediateBase", Transform(matrix:  handSkeleton.joint(.thumbIntermediateBase).parentFromJointTransform)),
                ("Wrist/ThumbKnuckle/ThumbIntermediateBase/ThumbIntermediateTip", Transform(matrix:  handSkeleton.joint(.thumbIntermediateTip).parentFromJointTransform)),
                ("Wrist/ThumbKnuckle/ThumbIntermediateBase/ThumbIntermediateTip/ThumbTip", Transform(matrix:  handSkeleton.joint(.thumbTip).parentFromJointTransform)),
                
                
                    ("Wrist/IndexFingerMetacarpal", Transform(matrix:  handSkeleton.joint(.indexFingerMetacarpal).parentFromJointTransform)),
                    ("Wrist/IndexFingerMetacarpal/IndexFingerKnuckle", Transform(matrix:  handSkeleton.joint(.indexFingerKnuckle).parentFromJointTransform)),
                    ("Wrist/IndexFingerMetacarpal/IndexFingerKnuckle/IndexFingerIntermediateBase", Transform(matrix:  handSkeleton.joint(.indexFingerIntermediateBase).parentFromJointTransform)),
                    ("Wrist/IndexFingerMetacarpal/IndexFingerKnuckle/IndexFingerIntermediateBase/IndexFingerIntermediateTip", Transform(matrix:  handSkeleton.joint(.indexFingerIntermediateTip).parentFromJointTransform)),
                    ("Wrist/IndexFingerMetacarpal/IndexFingerKnuckle/IndexFingerIntermediateBase/IndexFingerIntermediateTip/IndexFingerTip", Transform(matrix:  handSkeleton.joint(.indexFingerTip).parentFromJointTransform)),


                    ("Wrist/MiddleFingerMetacarpal", Transform(matrix:  handSkeleton.joint(.middleFingerMetacarpal).parentFromJointTransform)),
                    ("Wrist/MiddleFingerMetacarpal/MiddleFingerKnuckle", Transform(matrix:  handSkeleton.joint(.middleFingerKnuckle).parentFromJointTransform)),
                    ("Wrist/MiddleFingerMetacarpal/MiddleFingerKnuckle/MiddleFingerIntermediateBase", Transform(matrix:  handSkeleton.joint(.middleFingerIntermediateBase).parentFromJointTransform)),
                    ("Wrist/MiddleFingerMetacarpal/MiddleFingerKnuckle/MiddleFingerIntermediateBase/MiddleFingerIntermediateTip", Transform(matrix:  handSkeleton.joint(.middleFingerIntermediateTip).parentFromJointTransform)),
                    ("Wrist/MiddleFingerMetacarpal/MiddleFingerKnuckle/MiddleFingerIntermediateBase/MiddleFingerIntermediateTip/MiddleFingerTip", Transform(matrix:  handSkeleton.joint(.middleFingerTip).parentFromJointTransform)),


                    ("Wrist/RingFingerMetacarpal", Transform(matrix:  handSkeleton.joint(.ringFingerMetacarpal).parentFromJointTransform)),
                    ("Wrist/RingFingerMetacarpal/RingFingerKnuckle", Transform(matrix:  handSkeleton.joint(.ringFingerKnuckle).parentFromJointTransform)),
                    ("Wrist/RingFingerMetacarpal/RingFingerKnuckle/RingFingerIntermediateBase", Transform(matrix:  handSkeleton.joint(.ringFingerIntermediateBase).parentFromJointTransform)),
                    ("Wrist/RingFingerMetacarpal/RingFingerKnuckle/RingFingerIntermediateBase/RingFingerIntermediateTip", Transform(matrix:  handSkeleton.joint(.ringFingerIntermediateTip).parentFromJointTransform)),
                    ("Wrist/RingFingerMetacarpal/RingFingerKnuckle/RingFingerIntermediateBase/RingFingerIntermediateTip/RingFingerTip", Transform(matrix:  handSkeleton.joint(.ringFingerTip).parentFromJointTransform)),



                    ("Wrist/LittleFingerMetacarpal", Transform(matrix:  handSkeleton.joint(.littleFingerMetacarpal).parentFromJointTransform)),
                    ("Wrist/LittleFingerMetacarpal/LittleFingerKnuckle", Transform(matrix:  handSkeleton.joint(.littleFingerKnuckle).parentFromJointTransform)),
                    ("Wrist/LittleFingerMetacarpal/LittleFingerKnuckle/LittleFingerIntermediateBase", Transform(matrix:  handSkeleton.joint(.littleFingerIntermediateBase).parentFromJointTransform)),
                    ("Wrist/LittleFingerMetacarpal/LittleFingerKnuckle/LittleFingerIntermediateBase/LittleFingerIntermediateTip", Transform(matrix:  handSkeleton.joint(.littleFingerIntermediateTip).parentFromJointTransform)),
                    ("Wrist/LittleFingerMetacarpal/LittleFingerKnuckle/LittleFingerIntermediateBase/LittleFingerIntermediateTip/LittleFingerTip", Transform(matrix:  handSkeleton.joint(.littleFingerTip).parentFromJointTransform)),
            ])
            targetModel?.components[SkeletalPosesComponent.self]?.poses.default = skeletalPose
        }
    }


    
    public func removeHand(from handAnchor: HandAnchor) {
        if handAnchor.chirality == .left {
            left?.removeFromParent()
            left = nil
            leftModel = nil
        } else if handAnchor.chirality == .right { // Update right hand info.
            right?.removeFromParent()
            right = nil
            rightModel = nil
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



