//
//  DetailView.swift
//  RealityShadowPuppetry
//
//  Created by 许 on 2025/6/18.
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

    /// Toggle play/pause state
    private func togglePlayback() {
        guard model.turnOnImmersiveSpace else {
            print("Immersive space not turned on")
            return
        }
        
        
        if model.isVideoPlaying {
            // Currently playing, click to pause
            model.shadowMixManager?.videoPlayAndRenderCenter?.pause()
            print("User paused video")
        } else {
            // Currently paused, click to play
            model.shadowMixManager?.videoPlayAndRenderCenter?.play()
            print("User started playing video")
        }
    }
}

#Preview {
    DetailView()
}
