//
//  LifeReplayApp.swift
//  LifeReplay
//
//  Created by Madias Bek on 08.02.2026.
//

import SwiftUI
import SwiftData

@main
struct LifeReplayApp: App {
    
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: MindEntry.self)
    }
}
