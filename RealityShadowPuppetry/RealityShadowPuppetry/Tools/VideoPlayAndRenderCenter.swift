//
//  VideoPlayAndRenderCenter.swift
//  RealityShadowPuppetry
//
//  Created by 许M4 on 2025/10/13.
//

import MetalKit
@preconcurrency import AVFoundation


final class VideoPlayAndRenderCenter {
    var playerStatusDidChange: ((AVPlayer.TimeControlStatus) -> Void)?
    var playerItemStatusDidChange: ((AVPlayerItem.Status) -> Void)?
    var playbackDidFinish: (() -> Void)?
    
    var videoPixelUpdate: (() -> Void)?
    var lastestPixel: MTLTexture? {
        return customCompositor?.lastestPixel
    }
    
    private(set) var player: AVPlayer?
    
    
    // MARK: - Private Properties
    private var customCompositor: VideoCustomCompositor?
    private var timeControlStatusObserver: NSKeyValueObservation?
    private var playerItemStatusObserver: NSKeyValueObservation?
    private var playbackFinishedObserver: NSObjectProtocol?
    
    init(asset: AVAsset) async throws {
        let player = try await createPlayer(asset: asset)
        self.player = player
        self.customCompositor = player.currentItem?.customVideoCompositor as? VideoCustomCompositor
        
        self.customCompositor?.videoPixelUpdate = { [weak self] in
            self?.videoPixelUpdate?()
        }
        setupPlayerObservers()
    }
    

    public func clean() {
        removePlayerObservers()
        
        player?.pause()
        player?.seek(to: .zero)
        customCompositor?.cancelAllPendingVideoCompositionRequests()
        customCompositor?.lastestPixel = nil
        customCompositor?.videoPixelUpdate = nil
    }
    
    private func setupPlayerObservers() {
        guard let player = player else { return }
        
        // 监听播放控制状态变化 (playing, paused, waitingToPlayAtSpecifiedRate)
        timeControlStatusObserver = player.observe(\.timeControlStatus, options: [.new, .old]) { [weak self] player, change in
            DispatchQueue.main.async {
                self?.playerStatusDidChange?(player.timeControlStatus)
                print("Player status changed to: \(player.timeControlStatus)")
            }
        }
        
        // 监听播放项状态变化 (unknown, readyToPlay, failed)
        if let playerItem = player.currentItem {
            playerItemStatusObserver = playerItem.observe(\.status, options: [.new, .old]) { [weak self] playerItem, change in
                DispatchQueue.main.async {
                    self?.playerItemStatusDidChange?(playerItem.status)
                    print("PlayerItem status changed to: \(playerItem.status)")
                }
            }
        }
        
        // 监听播放完成通知
        playbackFinishedObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] notification in
            self?.playbackDidFinish?()
            print("Playback finished")
        }
    }
    
    private func removePlayerObservers() {
        timeControlStatusObserver?.invalidate()
        timeControlStatusObserver = nil
        
        playerItemStatusObserver?.invalidate()
        playerItemStatusObserver = nil
        
        if let playbackFinishedObserver = playbackFinishedObserver {
            NotificationCenter.default.removeObserver(playbackFinishedObserver)
            self.playbackFinishedObserver = nil
        }
        
        // 清理闭包引用
        playerStatusDidChange = nil
        playerItemStatusDidChange = nil
        playbackDidFinish = nil
    }
    private func createPlayer(asset: AVAsset) async throws -> AVPlayer {
        // Create a video composition with CustomCompositor
        let composition = try await AVMutableVideoComposition.videoComposition(withPropertiesOf: asset)
        composition.customVideoCompositorClass = VideoCustomCompositor.self
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.videoComposition = composition
        let player = AVPlayer(playerItem: playerItem)
        
        return player
    }
    
    
}
