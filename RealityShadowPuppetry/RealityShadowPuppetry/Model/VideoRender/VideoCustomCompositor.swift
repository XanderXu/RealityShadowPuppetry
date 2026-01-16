//
//  VideoCustomCompositor.swift
//  MPSAndCIFilterOnVisionOS
//
//  Created by 许 on 2025/6/25.
//

import Foundation
import AVFoundation
import RealityKit
import os

enum CustomCompositorError: Int, Error, LocalizedError, Sendable {
    case ciFilterFailedToProduceOutputImage = -1_000_001
    case notSupportingMoreThanOneSources

    var errorDescription: String? {
        switch self {
        case .ciFilterFailedToProduceOutputImage:
            return "CIFilter does not produce an output image."
        case .notSupportingMoreThanOneSources:
            return "This custom compositor does not support blending of more than one source."
        }
    }
}

nonisolated
final class VideoCustomCompositor: NSObject, AVVideoCompositing, @unchecked Sendable {
    // Thread-safe state container
    private struct State: Sendable {
        var videoPixelUpdate: (@Sendable () -> Void)?
        var lastestPixel: MTLTexture?
        var isCancelled = false
        var request: AVAsynchronousVideoCompositionRequest?
    }

    // Use OSAllocatedUnfairLock for better performance and proper Sendable conformance
    private let state = OSAllocatedUnfairLock(initialState: State())

    // Reusable Metal texture cache for better performance
    private let metalTextureCache: CVMetalTextureCache?

    // Thread-safe property accessors
    var videoPixelUpdate: (@Sendable () -> Void)? {
        get { state.withLock { $0.videoPixelUpdate } }
        set { state.withLock { $0.videoPixelUpdate = newValue } }
    }

    var lastestPixel: (any MTLTexture)? {
        get { state.withLock { $0.lastestPixel } }
        set {
            state.withLock { state in
                state.lastestPixel = newValue
            }
        }
    }

    var sourcePixelBufferAttributes: [String: any Sendable]? = [
        String(kCVPixelBufferPixelFormatTypeKey): [kCVPixelFormatType_32BGRA],
        String(kCVPixelBufferMetalCompatibilityKey): true // Critical!
    ]
    var requiredPixelBufferAttributesForRenderContext: [String: any Sendable] = [
        String(kCVPixelBufferPixelFormatTypeKey):[kCVPixelFormatType_32BGRA],
        String(kCVPixelBufferMetalCompatibilityKey): true
    ]

    override init() {
        // Initialize Metal device and texture cache once
        let metalDevice = MTLCreateSystemDefaultDevice()
        var cache: CVMetalTextureCache?

        if let device = metalDevice {
            let result = CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &cache)
            if result == kCVReturnSuccess {
                metalTextureCache = cache
            } else {
                metalTextureCache = nil
            }
        } else {
            metalTextureCache = nil
        }

        super.init()
    }

    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
        return
    }
    func cancelAllPendingVideoCompositionRequests() {
        state.withLock { state in
            state.isCancelled = true
            state.request?.finishCancelledRequest()
            state.request = nil
        }
    }

    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        state.withLock { state in
            state.request = request
            state.isCancelled = false
        }

//        guard let outputPixelBuffer = request.renderContext.newPixelBuffer() else {
//            print("No valid pixel buffer found. Returning.")
//            request.finish(with: CustomCompositorError.ciFilterFailedToProduceOutputImage)
//            return
//        }

        guard let requiredTrackIDs = request.videoCompositionInstruction.requiredSourceTrackIDs, !requiredTrackIDs.isEmpty else {
            print("No valid track IDs found in composition instruction.")
            return
        }

        let sourceCount = requiredTrackIDs.count

        if sourceCount > 1 {
            request.finish(with: CustomCompositorError.notSupportingMoreThanOneSources)
            return
        }

        if sourceCount == 1 {
            let sourceID = requiredTrackIDs[0]
            let sourceBuffer = request.sourceFrame(byTrackID: sourceID.value(of: Int32.self)!)!
            request.finish(withComposedVideoFrame: sourceBuffer)

            let metalTexture = convertToMetalTexture(sourceBuffer)

            // Atomically update state and get callback in one lock operation
            let callback = state.withLock { state -> (@Sendable () -> Void)? in
                state.lastestPixel = metalTexture
                return state.videoPixelUpdate
            }

            // Trigger update callback outside of lock
            Task { @MainActor in
                callback?()
            }
        }

//        request.finish(withComposedVideoFrame: outputPixelBuffer)
    }

    nonisolated func convertToMetalTexture(_ pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        guard let textureCache = metalTextureCache else {
            print("Metal texture cache not available")
            return nil
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        // Use cached texture cache instead of creating new one each time
        var cvTexture: CVMetalTexture?
        let result = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &cvTexture
        )

        guard result == kCVReturnSuccess,
              let cvTexture = cvTexture,
              let bgraTexture = CVMetalTextureGetTexture(cvTexture) else {
            print("Failed to create Metal texture from BGRA pixel buffer")
            print("CVPixelBuffer format: \(CVPixelBufferGetPixelFormatType(pixelBuffer))")
            print("Expected BGRA format: \(kCVPixelFormatType_32BGRA)")
            return nil
        }

        return bgraTexture
    }
}
