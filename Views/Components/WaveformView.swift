//
//  WaveformView.swift
//  LifeReplay
//
//  Created by Madias Bek on 08.02.2026.
//


import SwiftUI

struct WaveformView: View {
    let level: CGFloat
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<12, id: \.self) { i in
                Capsule()
                    .frame(width: 6, height: max(8, level * CGFloat(i + 4) * 30))
            }
        }
        .animation(.easeOut(duration: 0.1), value: level)
    }
}
