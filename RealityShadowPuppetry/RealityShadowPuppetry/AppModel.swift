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
    var videoShadowCenter: VideoShadowCenter?
    
    let handCenter = HandCenter()
    var turnOnImmersiveSpace = false
    var shadowStyle = ShadowStyle.Gray
    var showVideo = false
    var isPlaying = false {
        didSet {
            if isPlaying {
                videoShadowCenter?.player?.play()
            } else {
                videoShadowCenter?.player?.pause()
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
        videoShadowCenter = try await VideoShadowCenter(asset: asset)
//        videoShadowCenter?.playerStatusDidChange = { [weak self] status in
//            self?.isPlaying = status == .playing
//        }
        videoShadowCenter?.playbackDidFinish = { [weak self] in
            self?.videoShadowCenter?.player?.seek(to: .zero)
            self?.isPlaying = false
        }
    }
    func clear() {
        stopHandTracking()
        handCenter.clean()
        videoShadowCenter?.clean()
        videoShadowCenter = nil
        
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
        videoShadowCenter?.offscreenRenderer?.addEntity(handCenter.rootEntity)
    }
    func publishHandTrackingUpdates() async {
        for await update in handTracking.anchorUpdates {
            switch update.event {
            case .added, .updated:
                let anchor = update.anchor
                guard anchor.isTracked else {
                    continue
                }
                
            case .removed:
                let anchor = update.anchor
//                latestHandTracking.removeHand(from: anchor)
            }
            
            try? videoShadowCenter?.offscreenRenderer?.render()
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
            await handCenter.updateHand(from: simHand)
            
            videoShadowCenter?.offscreenRenderer?.addEntity(handCenter.rootEntity)
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
