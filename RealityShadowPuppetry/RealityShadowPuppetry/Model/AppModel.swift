//
//  AppModel.swift
//  RealityShadowPuppetry
//
//  Created by 许 on 2025/6/16.
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
                shadowMixManager?.videoPlayAndRenderCenter?.play()
            } else {
                shadowMixManager?.videoPlayAndRenderCenter?.pause()
            }
        }
    }
    var showOriginalVideo: Bool = false {
        didSet {
            shadowMixManager?.originalVideoEntity.isEnabled = showOriginalVideo
        }
    }
    
    var turnOnImmersiveSpace = false
    
    
    private let session = ARKitSession()
    private var worldTracking = WorldTrackingProvider()
    private var handTracking = HandTrackingProvider()
    private let simHandProvider = SimulatorHandTrackingProvider()
    init() {
        
    }
    func setup(asset: AVAsset, trackingType: ShadowMixManager.TrackingType) async throws {
        shadowMixManager = try await ShadowMixManager(asset: asset, trackingType: trackingType)
        
        // Set up playback completion callback
        shadowMixManager?.videoPlayAndRenderCenter?.playbackDidFinish = { [weak self] in
            self?.shadowMixManager?.videoPlayAndRenderCenter?.seek(to: .zero)
            self?.isVideoPlaying = false
        }
        
    }
    nonisolated
    func prepareHandModel() async throws {
        try await shadowMixManager?.loadModelEntity()
        await shadowMixManager?.cameraAutoLookHandCenter()
        try await shadowMixManager?.renderEntityShadowTextureAsync()
        await shadowMixManager?.populateFinalShadowIfNeeded()
    }
    nonisolated
    func prepareBodyModel() async throws {
        try await shadowMixManager?.loadModelEntity()
        await shadowMixManager?.cameraAutoLookHandCenter()
        try await shadowMixManager?.renderEntityShadowTextureAsync()
        await shadowMixManager?.populateFinalShadowIfNeeded()
    }
    
    func clear() {
        stopHandTracking()
        
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
    func startHandAndDeviceTracking() async {
        do {
            if HandTrackingProvider.isSupported {
                print("ARKitSession starting.")
                if WorldTrackingProvider.isSupported {
                    worldTracking = WorldTrackingProvider()
                    handTracking = HandTrackingProvider()
                    try await session.run([worldTracking, handTracking])
                } else {
                    handTracking = HandTrackingProvider()
                    try await session.run([handTracking])
                }
                
            }
        } catch {
            print("ARKitSession error:", error)
        }
    }
    func publishHandTrackingUpdates() async {
        var count = 0
        for await update in handTracking.anchorUpdates {
            switch update.event {
            case .added, .updated:
                let anchor = update.anchor
                print(anchor.chirality, update.event.description)
                var deviceTransform: simd_float4x4?
                if worldTracking.state == .running {
                    let device = worldTracking.queryDeviceAnchor(atTimestamp: anchor.timestamp)
                    deviceTransform = device?.originFromAnchorTransform
                }
                await shadowMixManager?.updateEntity(from: anchor, deviceMatrix: deviceTransform)
                if update.event == .added {
                    shadowMixManager?.cameraAutoLookHandCenter()
                }
            case .removed:
                let anchor = update.anchor
                shadowMixManager?.removeEntity(from: anchor)
            }
            count += 1
            if count % 5 == 0 {
                try? await shadowMixManager?.renderEntityShadowTextureAsync()
                shadowMixManager?.populateFinalShadowIfNeeded()
                count = 0
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
            await shadowMixManager?.updateHand(from: simHand)
            try? await shadowMixManager?.renderSimHandTextureAsync()
            shadowMixManager?.populateFinalShadowIfNeeded()
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
