//
//  RealityShadowPuppetryApp.swift
//  RealityShadowPuppetry
//
//  Created by 许M4 on 2025/6/16.
//

import SwiftUI

@main
struct RealityShadowPuppetryApp: App {

    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
        }

        .windowResizability(.contentSize)
        .defaultSize(width: 1, height: 0.6, depth: 0.1, in: .meters)

        ImmersiveSpace(id: Module.imageWithMPS.immersiveId) {
            ImageWithMPSImmersiveView()
                .environment(model)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
        
        ImmersiveSpace(id: Module.imageWithCIFilter.immersiveId) {
            ImageWithCIFilterImmersiveView()
                .environment(model)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
        
        
     }
}
