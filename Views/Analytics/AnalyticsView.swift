//
//  AnalyticsView.swift
//  LifeReplay
//
//  Created by Madias Bek on 08.02.2026.
//


import SwiftUI
import SwiftData
import Charts

struct AnalyticsView: View {
    
    @Query(sort: \MindEntry.timestamp, order: .reverse)
    private var entries: [MindEntry]
    
    @StateObject private var vm = AnalyticsViewModel()
    
    var body: some View {
        NavigationStack {
            let dashboard = vm.makeDashboard(entries: entries)
            
            ScrollView {
                VStack(spacing: 14) {
                    
                    headerControls
                    
                    statsRow(dashboard.stats)
                    
                    chartCard(title: "Intensity trend") {
                        if dashboard.daily.isEmpty {
                            emptyState("No data yet")
                        } else {
                            Chart(dashboard.daily) { p in
                                LineMark(
                                    x: .value("Day", p.day),
                                    y: .value("Avg", p.avgIntensity)
                                )
                                PointMark(
                                    x: .value("Day", p.day),
                                    y: .value("Avg", p.avgIntensity)
                                )
                            }
                            .chartYScale(domain: 0...5)
                            .frame(height: 200)
                        }
                    }
                    
                    chartCard(title: "Top emotions") {
                        barChart(dashboard.emotions)
                    }
                    
                    chartCard(title: "Growth areas") {
                        barChart(dashboard.areas)
                    }
                    
                    chartCard(title: "Entry types") {
                        barChart(dashboard.types)
                    }
                    
                    chartCard(title: "Loops (repeated patterns)") {
                        if dashboard.loops.isEmpty {
                            emptyState("No loops detected yet")
                        } else {
                            VStack(spacing: 10) {
                                ForEach(dashboard.loops) { loop in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(loop.loopKey.replacingOccurrences(of: "_", with: " "))
                                                .font(.system(size: 14, weight: .semibold))
                                            Text("\(loop.count)x • emotion: \(loop.topEmotion) • topic: \(loop.topTopic)")
                                                .font(.system(size: 12))
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(12)
                                    .background(Color.white.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 18)
                .padding(.top, 10)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Analytics")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
    
    private var headerControls: some View {
        VStack(spacing: 10) {
            HStack {
                Picker("Range", selection: $vm.range) {
                    ForEach(AnalyticsViewModel.RangeFilter.allCases) { r in
                        Text(r.rawValue).tag(r)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            HStack {
                Toggle("Compare", isOn: $vm.compareEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: .white.opacity(0.6)))
                Spacer()
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func statsRow(_ stats: [AnalyticsViewModel.StatRow]) -> some View {
        HStack(spacing: 10) {
            ForEach(stats) { s in
                VStack(alignment: .leading, spacing: 6) {
                    Text(s.title)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text(s.value)
                        .font(.system(size: 18, weight: .semibold))
                    if let delta = s.delta {
                        Text(delta)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }
    
    private func chartCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
            content()
        }
        .padding(12)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func barChart(_ items: [AnalyticsViewModel.CategoryCount]) -> some View {
        if items.isEmpty {
            return AnyView(emptyState("No data"))
        }
        
        let top = Array(items.prefix(8))
        
        return AnyView(
            Chart(top) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("Key", item.key)
                )
            }
            .frame(height: CGFloat(max(160, top.count * 26)))
        )
    }
    
    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 80)
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
