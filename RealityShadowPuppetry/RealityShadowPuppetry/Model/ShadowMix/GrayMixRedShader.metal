//
//  GrayMixRedShader.metal
//  RealityShadowPuppetry
//
//  Created by 许 on 2025/9/11.
//

#include <metal_stdlib>
using namespace metal;

/// Grayscale mixed with red channel compute shader
kernel void grayMixRedKernel(texture2d<float, access::read> videoTexture [[texture(0)]],
                             texture2d<float, access::read> offscreenTexture [[texture(1)]],
                             texture2d<float, access::write> outputTexture [[texture(2)]],
                             uint2 gid [[thread_position_in_grid]]) {
    
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    // Read pixel colors
    float4 videoColor = videoTexture.read(gid);
    float4 offscreenColor = offscreenTexture.read(gid);
    
    // Calculate grayscale values (using standard RGB to grayscale conversion formula)
    float videoGray = dot(videoColor.rgb, float3(0.299, 0.587, 0.114));
    float offscreenGray = dot(offscreenColor.rgb, float3(0.299, 0.587, 0.114));
    
    // Define threshold, grayscale values below this are considered "no value"
    float threshold = 0.001;
    
    float4 outputColor;
    
    if (videoGray > threshold && offscreenGray > threshold) {
        // Both grayscale values have values: add and write to red channel
        float combinedGray = min(videoGray + offscreenGray, 1.0);
        outputColor = float4(combinedGray, 0.0, 0.0, 1.0);
    } else {
        // At least one grayscale value is 0: display the larger value as grayscale image
        float maxGray = max(videoGray, offscreenGray);
        outputColor = float4(maxGray, maxGray, maxGray, videoColor.a);
    }
    
    outputTexture.write(outputColor, gid);
}
