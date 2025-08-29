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
                ForEach(AppModel.ShadowStyle.allCases, id: \.self) { type in
                    Text(type.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 40)
            .frame(width: 400)
            
            Toggle("Show Video", isOn: $model.showVideo)
                .disabled(!model.turnOnImmersiveSpace)
                .toggleStyle(ButtonToggleStyle())
                .padding(.bottom, 40)
                .frame(width: 400)
        }
    }
}

#Preview {
    DetailView()
}
