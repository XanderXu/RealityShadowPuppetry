//
//  AppModel.swift
//  RealityShadowPuppetry
//
//  Created by 许M4 on 2025/6/16.
//

import SwiftUI
import RealityKit
import ARKit
import AVFoundation

/// Maintains app-wide state
@MainActor
@Observable
class AppModel {
    
    var rootEntity: Entity?
    var shadowMixManager: ShadowMixManager?
    var shadowStyle: ShadowMixManager.ShadowMixStyle {
        get {
            shadowMixManager?.shadowStyle ?? .GrayAdd
        }
        set {
            shadowMixManager?.shadowStyle = newValue
        }
    }
    var isVideoPlaying = false {
        didSet {
            if isVideoPlaying {
                shadowMixManager?.play()
            } else {
                shadowMixManager?.pause()
            }
        }
    }
    var showOriginalVideo: Bool = false {
        didSet {
            shadowMixManager?.originalEntity.isEnabled = showOriginalVideo
        }
    }
    let handEntityManager = HandEntityManager()
    var turnOnImmersiveSpace = false
    
    
    private let session = ARKitSession()
//    private let worldTracking = WorldTrackingProvider()
    private var handTracking = HandTrackingProvider()
    private let simHandProvider = SimulatorHandTrackingProvider()
    init() {
        
    }
    func setup(asset: AVAsset) async throws {
        shadowMixManager = try await ShadowMixManager(asset: asset)
        
        // 设置播放完成回调
        shadowMixManager?.playbackDidFinish = { [weak self] in
            self?.shadowMixManager?.seek(to: .zero)
            self?.isVideoPlaying = false
        }
        
    }
    func prepareHandModel() async throws {
        try await handEntityManager.loadHandModelEntity()
        
        shadowMixManager?.offscreenRenderer?.addEntity(handEntityManager.rootEntity)
        shadowMixManager?.offscreenRenderer?.cameraAutoLookBoundingBoxCenter()
        // 执行初始渲染
        try shadowMixManager?.offscreenRenderer?.render()
    }
    func clear() {
        stopHandTracking()
        handEntityManager.clean()
        shadowMixManager?.clean()
        shadowMixManager = nil
        
        rootEntity?.children.removeAll()
        rootEntity?.removeFromParent()
    }
    
    /// Resets game state information.
    func reset() {
        debugPrint(#function)
        isVideoPlaying = false
        showOriginalVideo = false
        clear()
    }
    
    func stopHandTracking() {
        session.stop()
    }
    func startHandTracking() async {
        do {
            if HandTrackingProvider.isSupported {
                print("ARKitSession starting.")
                
                handTracking = HandTrackingProvider()
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
                print(anchor.chirality, update.event.description)
                await handEntityManager.updateHand(from: anchor)
                handEntityManager.updateHandModel(from: anchor)
                if update.event == .added {
                    shadowMixManager?.offscreenRenderer?.cameraAutoLookBoundingBoxCenter()
                }
            case .removed:
                let anchor = update.anchor
                handEntityManager.removeHand(from: anchor)
            }
            try? shadowMixManager?.offscreenRenderer?.render()
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
            await handEntityManager.updateHand(from: simHand)
            
            shadowMixManager?.offscreenRenderer?.addEntity(handEntityManager.rootEntity)
            shadowMixManager?.offscreenRenderer?.cameraLook(at: SIMD3<Float>(0, 1.4, 0), from: SIMD3<Float>(0, 1.4, 20))
            try? shadowMixManager?.offscreenRenderer?.render()
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
