//
//  AnalyticsViewModel.swift
//  LifeReplay
//
//  Created by Madias Bek on 08.02.2026.
//


import Foundation
import Combine

final class AnalyticsViewModel: ObservableObject {
    
    enum RangeFilter: String, CaseIterable, Identifiable {
        case last7 = "7D"
        case last30 = "30D"
        case all = "All"
        var id: String { rawValue }
    }
    
    @Published var range: RangeFilter = .last7
    @Published var compareEnabled: Bool = true
    
    struct StatRow: Identifiable {
        let id = UUID()
        let title: String
        let value: String
        let delta: String?
    }
    
    struct DailyPoint: Identifiable {
        let id = UUID()
        let day: Date
        let avgIntensity: Double
    }
    
    struct CategoryCount: Identifiable {
        let id = UUID()
        let key: String
        let count: Int
    }
    
    struct LoopRow: Identifiable {
        let id = UUID()
        let loopKey: String
        let count: Int
        let topEmotion: String
        let topTopic: String
    }
    
    // MARK: - Public computed
    
    func makeDashboard(entries: [MindEntry]) -> Dashboard {
        let now = Date()
        let (current, previous) = splitPeriods(entries: entries, now: now)
        
        let curStats = computeStats(entries: current)
        let prevStats = computeStats(entries: previous)
        
        let topEmotionCur = curStats.emotions.first?.key ?? "—"
        let topEmotionPrev = prevStats.emotions.first?.key ?? "—"
        
        let avgIntensityCur = curStats.avgIntensity
        let avgIntensityPrev = prevStats.avgIntensity
        
        let totalCur = current.count
        let totalPrev = previous.count
        
        let stats: [StatRow] = [
            StatRow(
                title: "Total entries",
                value: "\(totalCur)",
                delta: compareEnabled ? deltaText(current: Double(totalCur), prev: Double(totalPrev), isPercent: true) : nil
            ),
            StatRow(
                title: "Top emotion",
                value: topEmotionCur,
                delta: compareEnabled ? (topEmotionCur == topEmotionPrev ? "same" : "was \(topEmotionPrev)") : nil
            ),
            StatRow(
                title: "Avg intensity",
                value: String(format: "%.1f / 5", avgIntensityCur),
                delta: compareEnabled ? deltaText(current: avgIntensityCur, prev: avgIntensityPrev, isPercent: false) : nil
            )
        ]
        
        let daily = dailyTrend(entries: current)
        let emotions = curStats.emotions.map { CategoryCount(key: $0.key, count: $0.value) }
        let areas = curStats.areas.map { CategoryCount(key: $0.key, count: $0.value) }
        let types = curStats.types.map { CategoryCount(key: $0.key, count: $0.value) }
        let loops = loopRows(entries: current)
        
        return Dashboard(
            stats: stats,
            daily: daily,
            emotions: emotions,
            areas: areas,
            types: types,
            loops: loops
        )
    }
    
    struct Dashboard {
        let stats: [StatRow]
        let daily: [DailyPoint]
        let emotions: [CategoryCount]
        let areas: [CategoryCount]
        let types: [CategoryCount]
        let loops: [LoopRow]
    }
    
    // MARK: - Internals
    
    private func splitPeriods(entries: [MindEntry], now: Date) -> ([MindEntry], [MindEntry]) {
        let cal = Calendar.current
        
        let currentStart: Date? = {
            switch range {
            case .last7: return cal.date(byAdding: .day, value: -7, to: now)
            case .last30: return cal.date(byAdding: .day, value: -30, to: now)
            case .all: return nil
            }
        }()
        
        let current = entries.filter { e in
            guard let start = currentStart else { return true }
            return e.timestamp >= start && e.timestamp <= now
        }
        
        if !compareEnabled || range == .all {
            return (current, [])
        }
        
        let lengthDays: Int = (range == .last7) ? 7 : 30
        let prevEnd = currentStart ?? now
        let prevStart = cal.date(byAdding: .day, value: -lengthDays, to: prevEnd) ?? prevEnd
        
        let previous = entries.filter { e in
            e.timestamp >= prevStart && e.timestamp < prevEnd
        }
        
        return (current, previous)
    }
    
    private func computeStats(entries: [MindEntry]) -> Stats {
        let emotions = counts(entries.map { $0.primaryEmotion.lowercased() })
        let areas = counts(entries.map { $0.growthArea.lowercased() })
        let types = counts(entries.map { $0.entryType.lowercased() })
        
        let avgIntensity = entries.isEmpty ? 0.0 :
        Double(entries.map { max(1, min($0.emotionIntensity, 5)) }.reduce(0, +)) / Double(entries.count)
        
        return Stats(
            emotions: emotions,
            areas: areas,
            types: types,
            avgIntensity: avgIntensity
        )
    }
    
    private struct Stats {
        let emotions: [(key: String, value: Int)]
        let areas: [(key: String, value: Int)]
        let types: [(key: String, value: Int)]
        let avgIntensity: Double
    }
    
    private func counts(_ items: [String]) -> [(key: String, value: Int)] {
        let dict = Dictionary(grouping: items) { $0 }
            .mapValues { $0.count }
        return dict
            .sorted { $0.value > $1.value }
    }
    
    private func dailyTrend(entries: [MindEntry]) -> [DailyPoint] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: entries) { cal.startOfDay(for: $0.timestamp) }
        
        return grouped.map { day, list in
            let avg = list.isEmpty ? 0.0 :
            Double(list.map { max(1, min($0.emotionIntensity, 5)) }.reduce(0, +)) / Double(list.count)
            return DailyPoint(day: day, avgIntensity: avg)
        }
        .sorted { $0.day < $1.day }
    }
    
    private func loopRows(entries: [MindEntry]) -> [LoopRow] {
        let dict = Dictionary(grouping: entries) { e in
            e.loopKey.isEmpty ? "misc" : e.loopKey.lowercased()
        }
        
        let rows: [LoopRow] = dict.map { key, list in
            let emotions = Dictionary(grouping: list) { $0.primaryEmotion.lowercased() }
                .mapValues { $0.count }
                .sorted { $0.value > $1.value }
            
            let topicsFlat = list.flatMap { $0.topics.map { $0.lowercased() } }
            let topicsCounts = Dictionary(grouping: topicsFlat) { $0 }
                .mapValues { $0.count }
                .sorted { $0.value > $1.value }
            
            return LoopRow(
                loopKey: key,
                count: list.count,
                topEmotion: emotions.first?.key ?? "—",
                topTopic: topicsCounts.first?.key ?? "—"
            )
        }
        .sorted { $0.count > $1.count }
        
        return Array(rows.prefix(8))
    }
    
    private func deltaText(current: Double, prev: Double, isPercent: Bool) -> String {
        guard prev > 0 else { return "+∞" }
        let diff = current - prev
        if isPercent {
            let pct = (diff / prev) * 100.0
            let sign = pct >= 0 ? "+" : ""
            return "\(sign)\(Int(pct))%"
        } else {
            let sign = diff >= 0 ? "+" : ""
            return "\(sign)\(String(format: "%.1f", diff))"
        }
    }
}
