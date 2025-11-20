//
//  StereoDetailView.swift
//  RealityShadowPuppetry
//
//  Created by 许 on 2025/6/18.
//

import SwiftUI

struct StereoDetailView: View {
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
            
            Picker(selection: $model.stereoStyle, label: Text("Stereo Style")) {
                ForEach(StereoImageManager.StereoStyle.allCases, id: \.self) { type in
                    Text(type.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 40)
            .frame(width: 400)
            
            HStack(spacing: 20) {
                Toggle("Play Animation", isOn: $model.isStereoAnimationPlaying)
                    .disabled(!model.turnOnImmersiveSpace)
                    .toggleStyle(ButtonToggleStyle())
                    .padding(.bottom, 40)
                
            }
            
        }
    }

}

#Preview {
    DetailView()
}
