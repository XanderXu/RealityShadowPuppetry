//
//  DetailView.swift
//  RealityShadowPuppetry
//
//  Created by 许M4 on 2025/6/18.
//

import SwiftUI

struct DetailView: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        @Bindable var model = model
        VStack {
            VStack(alignment: .center, spacing: 10) {
                Toggle("Turn on Immersive Space", isOn: $model.turnOnImmersiveSpace)
                    .toggleStyle(ButtonToggleStyle())
                    .font(.system(size: 16, weight: .bold))
                    .padding(.bottom, 40)
                
            }
            
            Picker(selection: $model.shadowStyle, label: Text("Shadow Style")) {
                ForEach(ShadowMixManager.ShadowMixStyle.allCases, id: \.self) { type in
                    Text(type.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 40)
            .frame(width: 400)
            
            HStack(spacing: 20) {
                Toggle("Play Video", isOn: $model.isVideoPlaying)
                    .disabled(!model.turnOnImmersiveSpace)
                    .toggleStyle(ButtonToggleStyle())
                    .padding(.bottom, 40)
                
                Toggle("Show Original Video", isOn: $model.showOriginalVideo)
                    .disabled(!model.turnOnImmersiveSpace)
                    .toggleStyle(ButtonToggleStyle())
                    .padding(.bottom, 40)
            }
            
        }
    }

    /// 切换播放/暂停状态
    private func togglePlayback() {
        guard model.turnOnImmersiveSpace else {
            print("沉浸式空间未开启")
            return
        }
        
        guard let videoShadowCenter = model.shadowMixManager else {
            print("ShadowMixManager 不可用")
            return
        }
        
        if model.isVideoPlaying {
            // 当前正在播放，点击暂停
            videoShadowCenter.pause()
            print("用户暂停视频")
        } else {
            // 当前已暂停，点击播放
            videoShadowCenter.play()
            print("用户开始播放视频")
        }
        
        // 注意：不需要手动设置 model.isVideoPlaying
        // 因为 AppModel.setup() 中已经设置了播放状态监听
        // shadowMixManager.playerStatusDidChange 会自动更新 model.isVideoPlaying
    }
}

#Preview {
    DetailView()
}
