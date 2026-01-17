//
//  VideoPlayAndRenderCenter.swift
//  RealityShadowPuppetry
//
//  Created by 许 on 2025/10/13.
//

import MetalKit
import AVFoundation

final class VideoPlayAndRenderCenter {
    var playerStatusDidChange: (@Sendable (AVPlayer.TimeControlStatus) -> Void)?
    var playerItemStatusDidChange: (@Sendable (AVPlayerItem.Status) -> Void)?
    var playbackDidFinish: (() -> Void)?
    
    var latestPixel: MTLTexture? {
        return customCompositor?.latestPixel
    }

    /// the AVPlayer with customVideoCompositorClass can't play a tranparent video, it's probably a bug
    private(set) var player: AVPlayer?
    
    // MARK: - Private Properties
    private var customCompositor: VideoCustomCompositor?
    private var timeControlStatusObserver: NSKeyValueObservation?
    private var playerItemStatusObserver: NSKeyValueObservation?
    private var playbackFinishedObserver: NSObjectProtocol?

    // Stream for external consumers to listen to texture updates
    var updateStream: AsyncStream<Void>? {
        return customCompositor?.updateStream
    }
    
    init(asset: AVAsset) async throws {
        let player = try await createPlayer(asset: asset)
        self.player = player
        self.customCompositor = player.currentItem?.customVideoCompositor as? VideoCustomCompositor
        setupPlayerObservers()
    }
    
    public func play() {
        player?.play()
    }
    
    public func pause() {
        player?.pause()
    }
    
    public func seek(to time: CMTime) {
        player?.seek(to: time)
    }

    public func clean() {
        removePlayerObservers()

        player?.pause()
        player?.seek(to: .zero)

        // Clean up compositor
        customCompositor?.cancelAllPendingVideoCompositionRequests()
        customCompositor?.latestPixel = nil
    }
    
    private func setupPlayerObservers() {
        guard let player = player else { return }

        // Monitor playback control status changes (playing, paused, waitingToPlayAtSpecifiedRate)
        timeControlStatusObserver = player.observe(\.timeControlStatus, options: [.new, .old]) { [weak self] player, change in
            guard let self = self else { return }
            self.playerStatusDidChange?(player.timeControlStatus)
            print("Player status changed to: \(player.timeControlStatus)")
        }

        // Monitor player item status changes (unknown, readyToPlay, failed)
        if let playerItem = player.currentItem {
            playerItemStatusObserver = playerItem.observe(\.status, options: [.new, .old]) { [weak self] playerItem, change in
                guard let self = self else { return }
                self.playerItemStatusDidChange?(playerItem.status)
                print("PlayerItem status changed to: \(playerItem.status)")
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
