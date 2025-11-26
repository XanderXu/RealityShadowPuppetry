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
    
}
