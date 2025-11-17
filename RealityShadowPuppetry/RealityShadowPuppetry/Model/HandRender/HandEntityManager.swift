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
    private var left: Entity?
    private var right: Entity?
    private var leftModel: Entity?
    private var rightModel: Entity?
    
    
    func clean() {
        rootEntity.children.removeAll()
        left = nil
        right = nil
    }
    
    public func loadHandModelEntity() async throws {
//        left = try await Entity(named: "HandBone",in: realityKitContentBundle)
        left = try await Entity(named: "LeftHand12",in: realityKitContentBundle)
        left?.printHierarchyDetails()
        leftModel = left?.findFirstEntity(with: SkeletalPosesComponent.self)
        if let  poses = leftModel?.components[SkeletalPosesComponent.self] {
            print(poses.poses.default?.id ?? "", poses.poses.default?.jointNames ?? "")
        }
        
        /*
         Optional("/root/Armature/Armature")
         Optional(["Wrist", "Wrist/ThumbKnuckle", "Wrist/ThumbKnuckle/ThumbIntermediateBase", "Wrist/ThumbKnuckle/ThumbIntermediateBase/ThumbIntermediateTip", "Wrist/ThumbKnuckle/ThumbIntermediateBase/ThumbIntermediateTip/ThumbTip",
         "Wrist/IndexFingerMetacarpal", "Wrist/IndexFingerMetacarpal/IndexFingerKnuckle", "Wrist/IndexFingerMetacarpal/IndexFingerKnuckle/IndexFingerIntermediateBase", "Wrist/IndexFingerMetacarpal/IndexFingerKnuckle/IndexFingerIntermediateBase/IndexFingerIntermediateTip", "Wrist/IndexFingerMetacarpal/IndexFingerKnuckle/IndexFingerIntermediateBase/IndexFingerIntermediateTip/IndexFingerTip",
         "Wrist/MiddleFingerMetacarpal", "Wrist/MiddleFingerMetacarpal/MiddleFingerKnuckle", "Wrist/MiddleFingerMetacarpal/MiddleFingerKnuckle/MiddleFingerIntermediateBase", "Wrist/MiddleFingerMetacarpal/MiddleFingerKnuckle/MiddleFingerIntermediateBase/MiddleFingerIntermediateTip", "Wrist/MiddleFingerMetacarpal/MiddleFingerKnuckle/MiddleFingerIntermediateBase/MiddleFingerIntermediateTip/MiddleFingerTip",
         "Wrist/RingFingerMetacarpal", "Wrist/RingFingerMetacarpal/RingFingerKnuckle", "Wrist/RingFingerMetacarpal/RingFingerKnuckle/RingFingerIntermediateBase", "Wrist/RingFingerMetacarpal/RingFingerKnuckle/RingFingerIntermediateBase/RingFingerIntermediateTip", "Wrist/RingFingerMetacarpal/RingFingerKnuckle/RingFingerIntermediateBase/RingFingerIntermediateTip/RingFingerTip",
         "Wrist/LittleFingerMetacarpal", "Wrist/LittleFingerMetacarpal/LittleFingerKnuckle", "Wrist/LittleFingerMetacarpal/LittleFingerKnuckle/LittleFingerIntermediateBase", "Wrist/LittleFingerMetacarpal/LittleFingerKnuckle/LittleFingerIntermediateBase/LittleFingerIntermediateTip", "Wrist/LittleFingerMetacarpal/LittleFingerKnuckle/LittleFingerIntermediateBase/LittleFingerIntermediateTip/LittleFingerTip"])
         */
        if let left {
            rootEntity.addChild(left)
        }
    }
    
    public func updateHandModel(from handAnchor: HandAnchor) {
        if handAnchor.chirality == .left {
            left?.transform.matrix = handAnchor.originFromAnchorTransform
            if let handSkeleton = handAnchor.handSkeleton {
                let skeletalPose: SkeletalPose = .init(id: "/root/Armature/Armature", joints: [
                    ("Wrist/ThumbKnuckle", Transform(matrix:  handSkeleton.joint(.thumbKnuckle).parentFromJointTransform)),
                    ("Wrist/ThumbKnuckle/ThumbIntermediateBase", Transform(matrix:  handSkeleton.joint(.thumbIntermediateBase).parentFromJointTransform)),
                    ("Wrist/ThumbKnuckle/ThumbIntermediateBase/ThumbIntermediateTip", Transform(matrix:  handSkeleton.joint(.thumbIntermediateTip).parentFromJointTransform)),
                    ("Wrist/ThumbKnuckle/ThumbIntermediateBase/ThumbIntermediateTip/ThumbTip", Transform(matrix:  handSkeleton.joint(.thumbTip).parentFromJointTransform)),
                    
                    
//                    ("Wrist/IndexFingerMetacarpal", Transform(matrix:  handSkeleton.joint(.indexFingerMetacarpal).parentFromJointTransform)),
//                    ("Wrist/IndexFingerMetacarpal/IndexFingerKnuckle", Transform(matrix:  handSkeleton.joint(.indexFingerKnuckle).parentFromJointTransform)),
//                    ("Wrist/IndexFingerMetacarpal/IndexFingerKnuckle/IndexFingerIntermediateBase", Transform(matrix:  handSkeleton.joint(.indexFingerIntermediateBase).parentFromJointTransform)),
//                    ("Wrist/IndexFingerMetacarpal/IndexFingerKnuckle/IndexFingerIntermediateBase/IndexFingerIntermediateTip", Transform(matrix:  handSkeleton.joint(.indexFingerIntermediateTip).parentFromJointTransform)),
//                    ("Wrist/IndexFingerMetacarpal/IndexFingerKnuckle/IndexFingerIntermediateBase/IndexFingerIntermediateTip/IndexFingerTip", Transform(matrix:  handSkeleton.joint(.indexFingerTip).parentFromJointTransform)),
//
//
//                    ("Wrist/MiddleFingerMetacarpal", Transform(matrix:  handSkeleton.joint(.middleFingerMetacarpal).parentFromJointTransform)),
//                    ("Wrist/MiddleFingerMetacarpal/MiddleFingerKnuckle", Transform(matrix:  handSkeleton.joint(.middleFingerKnuckle).parentFromJointTransform)),
//                    ("Wrist/MiddleFingerMetacarpal/MiddleFingerKnuckle/MiddleFingerIntermediateBase", Transform(matrix:  handSkeleton.joint(.middleFingerIntermediateBase).parentFromJointTransform)),
//                    ("Wrist/MiddleFingerMetacarpal/MiddleFingerKnuckle/MiddleFingerIntermediateBase/MiddleFingerIntermediateTip", Transform(matrix:  handSkeleton.joint(.middleFingerIntermediateTip).parentFromJointTransform)),
//                    ("Wrist/MiddleFingerMetacarpal/MiddleFingerKnuckle/MiddleFingerIntermediateBase/MiddleFingerIntermediateTip/MiddleFingerTip", Transform(matrix:  handSkeleton.joint(.middleFingerTip).parentFromJointTransform)),
//
//
//                    ("Wrist/RingFingerMetacarpal", Transform(matrix:  handSkeleton.joint(.ringFingerMetacarpal).parentFromJointTransform)),
//                    ("Wrist/RingFingerMetacarpal/RingFingerKnuckle", Transform(matrix:  handSkeleton.joint(.ringFingerKnuckle).parentFromJointTransform)),
//                    ("Wrist/RingFingerMetacarpal/RingFingerKnuckle/RingFingerIntermediateBase", Transform(matrix:  handSkeleton.joint(.ringFingerIntermediateBase).parentFromJointTransform)),
//                    ("Wrist/RingFingerMetacarpal/RingFingerKnuckle/RingFingerIntermediateBase/RingFingerIntermediateTip", Transform(matrix:  handSkeleton.joint(.ringFingerIntermediateTip).parentFromJointTransform)),
//                    ("Wrist/RingFingerMetacarpal/RingFingerKnuckle/RingFingerIntermediateBase/RingFingerIntermediateTip/RingFingerTip", Transform(matrix:  handSkeleton.joint(.ringFingerTip).parentFromJointTransform)),
//
//
//
//                    ("Wrist/LittleFingerMetacarpal", Transform(matrix:  handSkeleton.joint(.littleFingerMetacarpal).parentFromJointTransform)),
//                    ("Wrist/LittleFingerMetacarpal/LittleFingerKnuckle", Transform(matrix:  handSkeleton.joint(.littleFingerKnuckle).parentFromJointTransform)),
//                    ("Wrist/LittleFingerMetacarpal/LittleFingerKnuckle/LittleFingerIntermediateBase", Transform(matrix:  handSkeleton.joint(.littleFingerIntermediateBase).parentFromJointTransform)),
//                    ("Wrist/LittleFingerMetacarpal/LittleFingerKnuckle/LittleFingerIntermediateBase/LittleFingerIntermediateTip", Transform(matrix:  handSkeleton.joint(.littleFingerIntermediateTip).parentFromJointTransform)),
//                    ("Wrist/LittleFingerMetacarpal/LittleFingerKnuckle/LittleFingerIntermediateBase/LittleFingerIntermediateTip/LittleFingerTip", Transform(matrix:  handSkeleton.joint(.littleFingerTip).parentFromJointTransform)),
                ])
                let prevSkeletalPose =  leftModel?.components[SkeletalPosesComponent.self]?.poses.set(skeletalPose)
                print("prevSkeletalPose: \(prevSkeletalPose)")
            }
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

extension simd_float4x4 {
    var xAxis: SIMD3<Float> {
        return SIMD3<Float>(columns.0.x, columns.0.y, columns.0.z)
    }
    var yAxis: SIMD3<Float> {
        return SIMD3<Float>(columns.1.x, columns.1.y, columns.1.z)
    }
    var zAxis: SIMD3<Float> {
        return SIMD3<Float>(columns.2.x, columns.2.y, columns.2.z)
    }
    var translation: SIMD3<Float> {
        return SIMD3<Float>(columns.3.x, columns.3.y, columns.3.z)
    }
    
    var rotation: simd_quatf {
        return simd_quatf(self)
    }
    
    var scale: SIMD3<Float> {
        return SIMD3<Float>(columns.0.x, columns.1.y, columns.2.z)
    }
    
    static func matrix(position: SIMD3<Float>, rotation: simd_quatf, scale: SIMD3<Float>) -> simd_float4x4 {
        return .init(columns: (
            .init(rotation.act([scale.x, 0, 0]), 0),
            .init(rotation.act([0, scale.y, 0]), 0),
            .init(rotation.act([0, 0, scale.z]), 0),
            .init(position, 1)
        ))
    }
    
    /// 根据欧拉角创建一个四元数旋转
    /// - Parameters:
    ///   - pitch: 绕X轴的俯仰角（弧度）
    ///   - yaw: 绕Y轴的偏航角（弧度）
    ///   - roll: 绕Z轴的翻滚角（弧度）
    /// - Returns: 组合后的旋转四元数
    func createRotationQuaternion(pitch: Float, yaw: Float, roll: Float) -> simd_quatf {
        // 1. 为每个轴创建单独的四元数
        let yawQuaternion = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))   // 绕Y轴
        let pitchQuaternion = simd_quatf(angle: pitch, axis: SIMD3<Float>(1, 0, 0)) // 绕X轴
        let rollQuaternion = simd_quatf(angle: roll, axis: SIMD3<Float>(0, 0, 1))  // 绕Z轴

        // 2. 按照正确的顺序将它们相乘
        // 外旋顺序 Z -> X -> Y 对应的乘法顺序是 Yaw * Pitch * Roll
        let combinedQuaternion = yawQuaternion * pitchQuaternion * rollQuaternion
        
        return combinedQuaternion
    }


    /// 根据欧拉角创建一个旋转矩阵
    /// - Parameters:
    ///   - pitch: 绕X轴的俯仰角（弧度）
    ///   - yaw: 绕Y轴的偏航角（弧度）
    ///   - roll: 绕Z轴的翻滚角（弧度）
    /// - Returns: 组合后的旋转矩阵
    func createRotationMatrix(pitch: Float, yaw: Float, roll: Float) -> simd_float4x4 {
        let yawQuaternion = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))   // 绕Y轴
        let pitchQuaternion = simd_quatf(angle: pitch, axis: SIMD3<Float>(1, 0, 0)) // 绕X轴
        let rollQuaternion = simd_quatf(angle: roll, axis: SIMD3<Float>(0, 0, 1))  // 绕Z轴

        // 1. 为每个轴创建单独的旋转矩阵
        let yawMatrix = simd_float4x4.init(columns: (
            .init(yawQuaternion.act([1, 0, 0]), 0),
            .init(yawQuaternion.act([0, 1, 0]), 0),
            .init(yawQuaternion.act([0, 0, 1]), 0),
            .init(.zero, 1)
        ))
        let pitchMatrix = simd_float4x4.init(columns: (
            .init(pitchQuaternion.act([1, 0, 0]), 0),
            .init(pitchQuaternion.act([0, 1, 0]), 0),
            .init(pitchQuaternion.act([0, 0, 1]), 0),
            .init(.zero, 1)
        ))
        let rollMatrix = simd_float4x4.init(columns: (
            .init(rollQuaternion.act([1, 0, 0]), 0),
            .init(rollQuaternion.act([0, 1, 0]), 0),
            .init(rollQuaternion.act([0, 0, 1]), 0),
            .init(.zero, 1)
        ))
    //
        // 2. 按照正确的顺序将它们相乘
        // 外旋顺序 Z -> X -> Y 对应的乘法顺序是 Yaw * Pitch * Roll
        let combinedMatrix = yawMatrix * pitchMatrix * rollMatrix

        return combinedMatrix
    }
    
}

