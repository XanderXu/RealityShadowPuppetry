//
//  AppModel.swift
//  RealityShadowPuppetry
//
//  Created by 许M4 on 2025/6/16.
//

import SwiftUI
import RealityKit

/// Maintains app-wide state
@MainActor
@Observable
class AppModel {
    enum ShadowStyle: String, CaseIterable {
        case Gray
        case Color
    }
    var rootEntity: Entity?
    var turnOnImmersiveSpace = false
    var shadowStyle = ShadowStyle.Gray
    var showVideo = false
    private let mtlDevice = MTLCreateSystemDefaultDevice()!
    
    func clear() {
        rootEntity?.children.removeAll()
        
    }
    
    /// Resets game state information.
    func reset() {
        debugPrint(#function)
        
        shadowStyle = ShadowStyle.Gray
        clear()
    }
    
    func createLowLevelTexture(width: Int, height: Int) throws -> LowLevelTexture {
        let textureDescriptor = createTextureDescriptor(width: width, height: height)
        let llt = try LowLevelTexture(descriptor: textureDescriptor)
        return llt
    }
    
    private func createTextureDescriptor(width: Int, height: Int) -> LowLevelTexture.Descriptor {
        var desc = LowLevelTexture.Descriptor()

        desc.textureType = .type2D
        desc.arrayLength = 1

        desc.width = width
        desc.height = height
        desc.depth = 1

        desc.mipmapLevelCount = 1
        desc.pixelFormat = .bgra8Unorm
        desc.textureUsage = [.shaderRead, .shaderWrite]
        desc.swizzle = .init(red: .red, green: .green, blue: .blue, alpha: .alpha)

        return desc
    }
}



/// A description of the modules that the app can present.
enum Module: String, Identifiable, CaseIterable, Equatable {
    case handShadow
    case bodyShadow
    
    var id: Self { self }
    var name: LocalizedStringKey {
        LocalizedStringKey(rawValue)
    }

    var immersiveId: String {
        self.rawValue + "ID"
    }

}
