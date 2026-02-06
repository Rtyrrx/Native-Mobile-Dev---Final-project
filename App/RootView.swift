//
//  RootView.swift
//  LifeReplay
//
//  Created by Madias Bek on 08.02.2026.
//

import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            
            ReplayView()
                .tabItem {
                    Label("Replay", systemImage: "clock")
                }
            RoomsView()
              .tabItem { Label("Replay", systemImage: "clock.arrow.circlepath") }

            
            CaptureView()
                .tabItem {
                    Label("Capture", systemImage: "mic")
                }
            
            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: "chart.bar")
                }
            AnalyticsView()
                .tabItem { Label("Analytics", systemImage: "chart.line.uptrend.xyaxis") }
             
        }
        .preferredColorScheme(.dark)
    }
}
