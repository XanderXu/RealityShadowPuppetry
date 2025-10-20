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
    
    private let rootEntity = Entity()
    private var left: Entity?
    private var right: Entity?
    private var leftModel: Entity?
    private var rightModel: Entity?
    
    private let offscreenRenderer: OffscreenRenderer?
    var rendererUpdate: (() -> Void)?  {
        didSet {
            offscreenRenderer?.rendererUpdate = rendererUpdate
        }
    }
    var colorTexture: MTLTexture? {
        return offscreenRenderer?.colorTexture
    }
    
    init(mtlDevice: MTLDevice, size: CGSize) throws {
        offscreenRenderer = try OffscreenRenderer(device: mtlDevice, textureSize: size)
        offscreenRenderer?.addEntity(rootEntity)
    }
    
    func renderAutoLookCenter() {
        offscreenRenderer?.cameraAutoLookBoundingBoxCenter()
    }
    
    func render() throws {
        try offscreenRenderer?.render()
    }
    func renderAsync() async throws {
        try await offscreenRenderer?.renderAsync()
    }
    
    func clean() {
        rootEntity.children.removeAll()
        left = nil
        right = nil
        
        rendererUpdate = nil
    }
    
    public func loadHandModelEntity() async throws {
        left = try await Entity(named: "HandBone",in: realityKitContentBundle)
        leftModel = left?.findFirstEntity(with: SkeletalPosesComponent.self)
        var poses = leftModel?.components[SkeletalPosesComponent.self]
        //        print(poses?.poses.first?.id, poses?.poses.first?.jointNames, poses?.poses.first?.jointTransforms)
        let lastMatrix = poses?.poses.default?.jointTransforms[20].matrix ?? .init(1)
        let indexTipsMatrix = poses?.poses.default?.jointTransforms[5].matrix ?? .init(1)
        poses?.poses.set(.init(id: "/root/scene/skin0/skeleton/skeleton", joints: [
            ("n9/n10/n28/n29", Transform(matrix:  lastMatrix * scaleMatrix2)),
            
            ("n9/n10/n11/n12/n13/n14", Transform(matrix: indexTipsMatrix * scaleMatrix2)),
            
        ]))
        
        leftModel?.components[SkeletalPosesComponent.self] = poses
        
        /*
         "/root/scene/skin0/skeleton/skeleton",
         ["n9", "n9/n10", "n9/n10/n11",
         "n9/n10/n11/n12", "n9/n10/n11/n12/n13", "n9/n10/n11/n12/n13/n14", "n9/n10/n11/n12/n13/n14/n15",
         "n9/n10/n11/n16", "n9/n10/n11/n16/n17", "n9/n10/n11/n16/n17/n18", "n9/n10/n11/n16/n17/n18/n19",
         "n9/n10/n11/n20", "n9/n10/n11/n20/n21", "n9/n10/n11/n20/n21/n22", "n9/n10/n11/n20/n21/n22/n23",
         "n9/n10/n11/n24", "n9/n10/n11/n24/n25", "n9/n10/n11/n24/n25/n26", "n9/n10/n11/n24/n25/n26/n27",
         "n9/n10/n28", "n9/n10/n28/n29", "n9/n10/n28/n29/n30"]
         */
        left?.position = simd_float3(0, 0.8, -20)
        left?.scale = simd_float3(0.002, 0.002, 0.002)
        if let left {
            rootEntity.addChild(left)
        }
    }
    private let scaleMatrix = simd_float4x4.matrix(position: .zero, rotation: .init(angle: 0, axis: [1, 0, 0]), scale: simd_float3(0.002, 0.002, 0.002))
    private let scaleMatrix2 = simd_float4x4.matrix(position: .zero, rotation: .init(angle: .pi/4, axis: [0, 1, 0]), scale: simd_float3(1, 1, 1))
    public func updateHandModel(from handAnchor: HandAnchor) {
        if handAnchor.chirality == .left {
            left?.transform.matrix = handAnchor.originFromAnchorTransform * scaleMatrix
            var poses = leftModel?.components[SkeletalPosesComponent.self]
    
            if let handSkeleton = handAnchor.handSkeleton {
                poses?.poses.set(.init(id: "/root/scene/skin0/skeleton/skeleton", joints: [
//                    ("n9", Transform(matrix: scaleMatrix2 * handSkeleton.joint(.wrist).parentFromJointTransform)),
//                    ("n9/n10", Transform(matrix: handSkeleton.joint(.thumbKnuckle).parentFromJointTransform)),
//                    ("n9/n10/n28", Transform(matrix: scaleMatrix2 * handSkeleton.joint(.thumbIntermediateBase).parentFromJointTransform)),
//                    ("n9/n10/n28/n29", Transform(matrix: scaleMatrix2 * handSkeleton.joint(.thumbIntermediateTip).parentFromJointTransform)),
                    ("n9/n10/n28/n29/n30", Transform(matrix:  handSkeleton.joint(.thumbTip).parentFromJointTransform * scaleMatrix2)),
                    
                    
//                    ("n9/n10/n11", Transform(matrix: scaleMatrix2 * handSkeleton.joint(.indexFingerKnuckle).parentFromJointTransform)),
//                    ("n9/n10/n11/n12", Transform(matrix: scaleMatrix2 * handSkeleton.joint(.indexFingerIntermediateBase).parentFromJointTransform)),
//                    ("n9/n10/n11/n12/n13", Transform(matrix: scaleMatrix2 * handSkeleton.joint(.indexFingerIntermediateTip).parentFromJointTransform)),
                    ("n9/n10/n11/n12/n13/n14", Transform(matrix: handSkeleton.joint(.indexFingerTip).parentFromJointTransform * scaleMatrix2)),
                    
                ]))
                
                leftModel?.components[SkeletalPosesComponent.self] = poses
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
    
    public func renderSimHand() throws {
        offscreenRenderer?.addEntity(rootEntity)
        offscreenRenderer?.cameraLook(at: SIMD3<Float>(0, 1.4, 0), from: SIMD3<Float>(0, 1.4, 20))
        try offscreenRenderer?.render()
    }
}

fileprivate extension simd_float4x4 {
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
