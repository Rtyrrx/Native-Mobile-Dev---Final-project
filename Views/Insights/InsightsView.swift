//
//  InsightsView.swift
//  LifeReplay
//
//  Created by Madias Bek on 08.02.2026.
//
import SwiftUI
import SwiftData

struct InsightsView: View {
    
    @Query(sort: \MindEntry.timestamp, order: .reverse)
    private var entries: [MindEntry]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    
                    statCard(title: "Total Entries", value: "\(entries.count)")
                    statCard(title: "Average Intensity", value: String(format: "%.1f", averageIntensity()))
                    
                    if let commonEmotion = mostCommonEmotion() {
                        statCard(title: "Most Common Emotion", value: commonEmotion.capitalized)
                    }
                    
                    if let commonArea = mostCommonGrowthArea() {
                        statCard(title: "Main Growth Focus", value: commonArea.capitalized)
                    }
                    
                    Divider().padding(.vertical, 8)
                    
                    Text("Loop Signals")
                        .font(.headline)
                    
                    let loops = emotionLoopSignals()
                    if loops.isEmpty {
                        Text("No clear loops yet. Log more entries.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(loops, id: \.self) { line in
                            Text("• \(line)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Divider().padding(.vertical, 8)
                    
                    Text("Last 7 Days")
                        .font(.headline)
                    
                    let week = weeklyEmotionCounts()
                    if week.isEmpty {
                        Text("Not enough data for weekly stats.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(week.sorted(by: { $0.value > $1.value }), id: \.key) { key, value in
                            Text("• \(key.capitalized): \(value)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Insights")
        }
    }
    
    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold())
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func averageIntensity() -> Double {
        guard !entries.isEmpty else { return 0 }
        let total = entries.map { $0.emotionIntensity }.reduce(0, +)
        return Double(total) / Double(entries.count)
    }
    
    private func mostCommonEmotion() -> String? {
        let grouped = Dictionary(grouping: entries, by: { $0.primaryEmotion.lowercased() })
        return grouped.max { $0.value.count < $1.value.count }?.key
    }
    
    private func mostCommonGrowthArea() -> String? {
        let grouped = Dictionary(grouping: entries, by: { $0.growthArea.lowercased() })
        return grouped.max { $0.value.count < $1.value.count }?.key
    }
    
    private func emotionLoopSignals() -> [String] {
        guard entries.count >= 5 else { return [] }
        
        let recent = Array(entries.prefix(14))
        
        let grouped = Dictionary(grouping: recent, by: { $0.primaryEmotion.lowercased() })
        let sorted = grouped.sorted { $0.value.count > $1.value.count }
        
        var signals: [String] = []
        
        if let top = sorted.first, top.value.count >= 5 {
            signals.append("You logged “\(top.key)” \(top.value.count) times recently.")
        }
        
        let high = recent.filter { $0.emotionIntensity >= 4 }
        if high.count >= 4 {
            signals.append("High intensity (4–5) appears \(high.count) times recently.")
        }
        
        return signals
    }
    
    private func weeklyEmotionCounts() -> [String: Int] {
        let now = Date()
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        
        let lastWeek = entries.filter { $0.timestamp >= weekAgo }
        guard !lastWeek.isEmpty else { return [:] }
        
        let grouped = Dictionary(grouping: lastWeek, by: { $0.primaryEmotion.lowercased() })
        return grouped.mapValues { $0.count }
    }
}

