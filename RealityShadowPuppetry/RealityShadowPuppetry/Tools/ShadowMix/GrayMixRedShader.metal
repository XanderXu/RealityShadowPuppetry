//
//  GrayMixRedShader.metal
//  RealityShadowPuppetry
//
//  Created by 许 on 2025/9/11.
//

#include <metal_stdlib>
using namespace metal;

/// 灰度混合红色通道计算着色器
/// @param videoTexture 视频纹理（已转换为灰度）
/// @param offscreenTexture 离屏纹理（已转换为灰度）
/// @param outputTexture 输出纹理
/// @param gid 线程位置
kernel void grayMixRedKernel(texture2d<float, access::read> videoTexture [[texture(0)]],
                             texture2d<float, access::read> offscreenTexture [[texture(1)]],
                             texture2d<float, access::write> outputTexture [[texture(2)]],
                             uint2 gid [[thread_position_in_grid]]) {
    
    // 边界检查
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    // 读取像素颜色
    float4 videoColor = videoTexture.read(gid);
    float4 offscreenColor = offscreenTexture.read(gid);
    
    // 计算灰度值（使用标准的RGB到灰度转换公式）
    float videoGray = dot(videoColor.rgb, float3(0.299, 0.587, 0.114));
    float offscreenGray = dot(offscreenColor.rgb, float3(0.299, 0.587, 0.114));
    
    // 定义阈值，低于此值的灰度被视为"无值"
    float threshold = 0.001;
    
    float4 outputColor;
    
    if (videoGray > threshold && offscreenGray > threshold) {
        // 两个灰度都有值：相加并写入红色通道
        float combinedGray = min(videoGray + offscreenGray, 1.0);
        outputColor = float4(combinedGray, 0.0, 0.0, 1.0);
    } else {
        // 至少有一个灰度值为0：显示较大值作为灰度图
        float maxGray = max(videoGray, offscreenGray);
        outputColor = float4(maxGray, maxGray, maxGray, videoColor.a);
    }
    
    outputTexture.write(outputColor, gid);
}
