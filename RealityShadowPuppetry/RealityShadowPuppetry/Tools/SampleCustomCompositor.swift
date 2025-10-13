//
//  SampleCustomCompositor.swift
//  MPSAndCIFilterOnVisionOS
//
//  Created by 许M4 on 2025/6/25.
//

import Foundation
import AVFoundation
import MetalPerformanceShaders
import RealityKit

enum CustomCompositorError: Int, Error, LocalizedError {
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
final class SampleCustomCompositor: NSObject, AVVideoCompositing, @unchecked Sendable {
    
    var videoPixelUpdate: (() -> Void)?
    
    var lastestPixel: (any MTLTexture)?
    
    private var isCancelled = false
    private var request: AVAsynchronousVideoCompositionRequest?
    var sourcePixelBufferAttributes: [String: any Sendable]? = [
        String(kCVPixelBufferPixelFormatTypeKey): [kCVPixelFormatType_32BGRA],
        String(kCVPixelBufferMetalCompatibilityKey): true // Critical!
    ]
    var requiredPixelBufferAttributesForRenderContext: [String: any Sendable] = [
        String(kCVPixelBufferPixelFormatTypeKey):[kCVPixelFormatType_32BGRA],
        String(kCVPixelBufferMetalCompatibilityKey): true
    ]
 
    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
        return
    }
    func cancelAllPendingVideoCompositionRequests() {
        isCancelled = true
        request?.finishCancelledRequest()
        request = nil
    }
    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        self.request = request
        isCancelled = false  // 重置取消状态
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
            Task {
                self.lastestPixel = await self.convertToMetalTexture(sourceBuffer)
                self.videoPixelUpdate?()
            }
        }
        
//        request.finish(withComposedVideoFrame: outputPixelBuffer)
    }
    @concurrent
    func convertToMetalTexture(_ pixelBuffer: CVPixelBuffer) async -> MTLTexture? {
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Failed to create Metal device")
            return nil
        }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        // Now sourceBuffer should already be in BGRA format, create Metal texture directly
        var mtlTextureCache: CVMetalTextureCache? = nil
        let cacheResult = CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &mtlTextureCache)
        guard cacheResult == kCVReturnSuccess, let textureCache = mtlTextureCache else {
            print("Failed to create Metal texture cache")
            return nil
        }
        // 确保在函数结束时清理缓存
        defer {
            CVMetalTextureCacheFlush(textureCache, 0)
        }
        
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
