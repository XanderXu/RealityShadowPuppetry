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
    var inTexture: MTLTexture?
    var lowLevelTexture: LowLevelTexture?
    
    func clear() {
        rootEntity?.children.removeAll()
        inTexture = nil
        lowLevelTexture = nil
    }
    
    /// Resets game state information.
    func reset() {
        debugPrint(#function)
        
        shadowStyle = ShadowStyle.Gray
        clear()
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
