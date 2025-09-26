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
    var rootEntity2: Entity?
    var videoShadowManager: VideoShadowManager?
    var shadowStyle: VideoShadowManager.ShadowMixStyle {
        get {
            videoShadowManager?.shadowStyle ?? .GrayAdd
        }
        set {
            videoShadowManager?.shadowStyle = newValue
        }
    }
    var isVideoPlaying = false {
        didSet {
            if isVideoPlaying {
                videoShadowManager?.player?.play()
            } else {
                videoShadowManager?.player?.pause()
            }
        }
    }
    var showOriginalVideo: Bool = false {
        didSet {
            videoShadowManager?.originalEntity.isEnabled = showOriginalVideo
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
        videoShadowManager = try await VideoShadowManager(asset: asset)
//        videoShadowManager?.playerStatusDidChange = { [weak self] status in
//            self?.isVideoPlaying = status == .playing
//        }
        videoShadowManager?.playbackDidFinish = { [weak self] in
            self?.videoShadowManager?.player?.seek(to: .zero)
            self?.isVideoPlaying = false
        }
        
    }
    func loadModel() async throws {
        try await handEntityManager.loadHandModelEntity()
        
        // 先清理之前的实体
        videoShadowManager?.offscreenRenderer?.removeAllEntities()
        
        // 直接添加手部实体到离屏渲染器
        videoShadowManager?.offscreenRenderer?.addEntity(handEntityManager.rootEntity)
        
        // 设置相机位置和视角
        videoShadowManager?.offscreenRenderer?.cameraLook(at: SIMD3<Float>(0, 0.8, 0), from: SIMD3<Float>(0, 0.8, 1))
        
        // 执行初始渲染
        try videoShadowManager?.offscreenRenderer?.render()
        
//        rootEntity?.addChild(handEntityManager.rootEntity)
    }
    func clear() {
        stopHandTracking()
        handEntityManager.clean()
        videoShadowManager?.clean()
        videoShadowManager = nil
        
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
                if update.event == .added {
                    videoShadowManager?.offscreenRenderer?.cameraAutoLookBoundingBoxCenter()
                }
            case .removed:
                let anchor = update.anchor
                handEntityManager.removeHand(from: anchor)
            }
            try? videoShadowManager?.offscreenRenderer?.render()
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
            
            videoShadowManager?.offscreenRenderer?.addEntity(handEntityManager.rootEntity)
            videoShadowManager?.offscreenRenderer?.cameraLook(at: SIMD3<Float>(0, 1.4, 0), from: SIMD3<Float>(0, 1.4, 20))
            try? videoShadowManager?.offscreenRenderer?.render()
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
