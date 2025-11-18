//
//  SIMD+Extension.swift
//  RealityShadowPuppetry
//
//  Created by 许同学 on 2025/11/18.
//

import RealityKit

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
