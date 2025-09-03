//
//  AppModel.swift
//  RealityShadowPuppetry
//
//  Created by 许M4 on 2025/6/16.
//

import SwiftUI
import RealityKit
import ARKit
import HandVector

/// Maintains app-wide state
@MainActor
@Observable
class AppModel {
    enum ShadowStyle: String, CaseIterable {
        case Gray
        case Color
    }
    var rootEntity: Entity?
    var videoShadowCenter: VideoShadowCenter?
    
    var turnOnImmersiveSpace = false
    var shadowStyle = ShadowStyle.Gray
    var showVideo = false
    
    
    var latestHandTracking: HandVectorManager = .init(left: nil, right: nil)
    private let session = ARKitSession()
    private let worldTracking = WorldTrackingProvider()
    private let handTracking = HandTrackingProvider()
    private let simHandProvider = SimulatorHandTrackingProvider()
    
    
    init() {
        self.latestHandTracking.isSkeletonVisible = true
    }
    func clear() {
        latestHandTracking.left?.removeFromParent()
        latestHandTracking.right?.removeFromParent()
        rootEntity?.children.removeAll()
        rootEntity?.removeFromParent()
        videoShadowCenter?.clean()
        videoShadowCenter = nil
    }
    
    /// Resets game state information.
    func reset() {
        debugPrint(#function)
        
        shadowStyle = ShadowStyle.Gray
        clear()
    }
    
    
    func startHandTracking() async {
        do {
            if HandTrackingProvider.isSupported {
                print("ARKitSession starting.")
                try await session.run([handTracking])
            }
        } catch {
            print("ARKitSession error:", error)
        }
        
    }
    
    func publishHandTrackingUpdates() async {
        for await update in handTracking.anchorUpdates {
            switch update.event {
            case .added, .updated:
                let anchor = update.anchor
                guard anchor.isTracked else {
                    continue
                }
                let handInfo = latestHandTracking.generateHandInfo(from: anchor)
                if let handInfo {
                    await latestHandTracking.updateHandSkeletonEntity(from: handInfo)
                    if let left = latestHandTracking.left {
                        rootEntity?.addChild(left)
                    }
                    if let right = latestHandTracking.right {
                        rootEntity?.addChild(right)
                    }
                }
            case .removed:
                let anchor = update.anchor
                latestHandTracking.removeHand(from: anchor)
            }
        }
    }
    
    func monitorSessionEvents() async {
        for await event in session.events {
            switch event {
            case .authorizationChanged(let type, let status):
                if type == .handTracking && status != .allowed {
                    // Stop the game, ask the user to grant hand tracking authorization again in Settings.
                    print("handTracking authorizationChanged \(status)")
                }
            default:
                print("Session event \(event)")
            }
        }
    }
    
    func publishSimHandTrackingUpdates() async {
        for await simHand in simHandProvider.simHands {
            if simHand.landmarks.isEmpty { continue }
            await latestHandTracking.updateHand(from: simHand)
            if let left = latestHandTracking.left {
                videoShadowCenter?.offscreenRenderer?.addEntity(left)
//                rootEntity?.addChild(left)
            }
            if let right = latestHandTracking.right {
//                videoShadowCenter?.offscreenRenderer?.addEntity(right)
//                rootEntity?.addChild(right)
            }
            try? videoShadowCenter?.offscreenRenderer?.render()
        }
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
