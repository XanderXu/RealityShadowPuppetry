//
//  VideoPlayAndRenderCenter.swift
//  RealityShadowPuppetry
//
//  Created by 许 on 2025/10/13.
//

import MetalKit
import AVFoundation

final class VideoPlayAndRenderCenter: @unchecked Sendable {
    var playerStatusDidChange: (@Sendable (AVPlayer.TimeControlStatus) -> Void)?
    var playerItemStatusDidChange: (@Sendable (AVPlayerItem.Status) -> Void)?
    var playbackDidFinish: (() -> Void)?
    
    var videoPixelUpdate: (() -> Void)?
    var lastestPixel: MTLTexture? {
        return customCompositor?.lastestPixel
    }
    
    /// the AVPlayer with customVideoCompositorClass can't play a tranparent video, it's probably a bug
    private(set) var player: AVPlayer?
    /// the AVPlayer without customVideoCompositorClass, can play a tranparent video
    private(set) var transparentPlayer: AVPlayer?
    
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
        self.transparentPlayer = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        setupPlayerObservers()
    }
    
    public func play() {
        transparentPlayer?.play()
        player?.play()
    }
    
    public func pause() {
        transparentPlayer?.pause()
        player?.pause()
    }
    
    public func seek(to time: CMTime) {
        transparentPlayer?.seek(to: time)
        player?.seek(to: time)
    }

    public func clean() {
        removePlayerObservers()
        
        transparentPlayer?.pause()
        transparentPlayer?.seek(to: .zero)
        player?.pause()
        player?.seek(to: .zero)
        customCompositor?.cancelAllPendingVideoCompositionRequests()
        customCompositor?.lastestPixel = nil
        customCompositor?.videoPixelUpdate = nil
    }
    
    private func setupPlayerObservers() {
        guard let player = player else { return }

        // Monitor playback control status changes (playing, paused, waitingToPlayAtSpecifiedRate)
        timeControlStatusObserver = player.observe(\.timeControlStatus, options: [.new, .old]) { [weak self] player, change in
            self?.handleTimeControlStatusChange(player.timeControlStatus)
        }

        // Monitor player item status changes (unknown, readyToPlay, failed)
        if let playerItem = player.currentItem {
            playerItemStatusObserver = playerItem.observe(\.status, options: [.new, .old]) { [weak self] playerItem, change in
                self?.handlePlayerItemStatusChange(playerItem.status)
            }
        }
        
        // Listen for playback completion notification
        playbackFinishedObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] notification in
            self?.playbackDidFinish?()
            print("Playback finished")
        }
    }

    private nonisolated func handleTimeControlStatusChange(_ status: AVPlayer.TimeControlStatus) {
        Task { @MainActor [weak self] in
            self?.playerStatusDidChange?(status)
            print("Player status changed to: \(status)")
        }
    }

    private nonisolated func handlePlayerItemStatusChange(_ status: AVPlayerItem.Status) {
        Task { @MainActor [weak self] in
            self?.playerItemStatusDidChange?(status)
            print("PlayerItem status changed to: \(status)")
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
        
        // Clean up closure references
        playerStatusDidChange = nil
        playerItemStatusDidChange = nil
        playbackDidFinish = nil
        videoPixelUpdate = nil
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
