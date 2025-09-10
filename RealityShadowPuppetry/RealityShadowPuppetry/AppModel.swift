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
    enum ShadowStyle: String, CaseIterable {
        case Gray
        case Color
    }
    var rootEntity: Entity?
    var videoShadowManager: VideoShadowManager?
    
    let handEntityManager = HandEntityManager()
    var turnOnImmersiveSpace = false
    var shadowStyle = ShadowStyle.Gray
    var showVideo = false
    var isPlaying = false {
        didSet {
            if isPlaying {
                videoShadowManager?.player?.play()
            } else {
                videoShadowManager?.player?.pause()
            }
        }
    }
    
    
    private let session = ARKitSession()
//    private let worldTracking = WorldTrackingProvider()
    private let handTracking = HandTrackingProvider()
    private let simHandProvider = SimulatorHandTrackingProvider()
    init() {
        
    }
    func setup(asset: AVAsset) async throws {
        videoShadowManager = try await VideoShadowManager(asset: asset)
//        videoShadowManager?.playerStatusDidChange = { [weak self] status in
//            self?.isPlaying = status == .playing
//        }
        videoShadowManager?.playbackDidFinish = { [weak self] in
            self?.videoShadowManager?.player?.seek(to: .zero)
            self?.isPlaying = false
        }
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
        
        shadowStyle = ShadowStyle.Gray
        clear()
    }
    
    func stopHandTracking() {
        session.stop()
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
        videoShadowManager?.offscreenRenderer?.addEntity(handEntityManager.rootEntity)
        videoShadowManager?.offscreenRenderer?.cameraLook(at: SIMD3<Float>(0, 1.4, 0), from: SIMD3<Float>(0, 1.4, 20))
    }
    func publishHandTrackingUpdates() async {
        for await update in handTracking.anchorUpdates {
            switch update.event {
            case .added, .updated:
                let anchor = update.anchor
                await handEntityManager.updateHand(from: anchor)
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
