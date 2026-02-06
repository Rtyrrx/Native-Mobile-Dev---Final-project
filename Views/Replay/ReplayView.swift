import SwiftUI
import SwiftData

struct ReplayView: View {
    
    @Query(sort: \MindEntry.timestamp, order: .reverse)
    private var entries: [MindEntry]
    
    @State private var timeFilter: TimeFilter = .all
    @State private var growthFilter: GrowthFilter = .all
    @State private var emotionFilter: String = "All"
    @State private var showTree: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                
                filtersBar
                
                if showTree {
                    TreeReplayView(entries: filteredEntries, mode: .emotion)
                } else {
                    dayGroupedList
                }
            }
            .navigationTitle("Life Replay")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showTree.toggle()
                    } label: {
                        Image(systemName: showTree ? "list.bullet" : "point.3.connected.trianglepath.dotted")
                    }
                }
            }
        }
    }
    
    // MARK: - Filters UI
    
    private var filtersBar: some View {
        VStack(spacing: 8) {
            
            HStack(spacing: 8) {
                Picker("Time", selection: $timeFilter) {
                    ForEach(TimeFilter.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            HStack(spacing: 8) {
                Picker("Area", selection: $growthFilter) {
                    ForEach(GrowthFilter.allCases) { item in
                        Text(item == .all ? "Area" : item.rawValue.capitalized)
                            .tag(item)
                    }
                }
                .pickerStyle(.menu)
                
                Picker("Emotion", selection: $emotionFilter) {
                    Text("Emotion").tag("All")
                    ForEach(availableEmotions, id: \.self) { e in
                        Text(e.capitalized).tag(e)
                    }
                }
                .pickerStyle(.menu)
                
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.top, 6)
    }
    
    // MARK: - List grouped by day
    
    private var dayGroupedList: some View {
        List {
            ForEach(daySections, id: \.date) { section in
                Section {
                    ForEach(section.items) { entry in
                        NavigationLink {
                            MindEntryDetailView(entry: entry)
                        } label: {
                            MindEntryRow(entry: entry)
                        }
                    }
                } header: {
                    Text(sectionTitle(for: section.date))
                        .font(.headline)
                        .textCase(nil)
                }
            }
        }
    }
    
    // MARK: - Data
    
    private var filteredEntries: [MindEntry] {
        entries
            .filter(applyTimeFilter)
            .filter(applyGrowthFilter)
            .filter(applyEmotionFilter)
    }
    
    private var availableEmotions: [String] {
        let set = Set(entries.map { $0.primaryEmotion.lowercased() })
        return set.sorted()
    }
    
    private func applyTimeFilter(_ entry: MindEntry) -> Bool {
        let now = Date()
        let cal = Calendar.current
        
        switch timeFilter {
        case .all:
            return true
        case .today:
            return cal.isDateInToday(entry.timestamp)
        case .last7:
            let from = cal.date(byAdding: .day, value: -7, to: now) ?? now
            return entry.timestamp >= from
        case .last30:
            let from = cal.date(byAdding: .day, value: -30, to: now) ?? now
            return entry.timestamp >= from
        }
    }
    
    private func applyGrowthFilter(_ entry: MindEntry) -> Bool {
        guard growthFilter != .all else { return true }
        return entry.growthArea.lowercased() == growthFilter.rawValue.lowercased()
    }
    
    private func applyEmotionFilter(_ entry: MindEntry) -> Bool {
        guard emotionFilter != "All" else { return true }
        return entry.primaryEmotion.lowercased() == emotionFilter.lowercased()
    }
    
    private var daySections: [DaySection] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: filteredEntries) { entry in
            cal.startOfDay(for: entry.timestamp)
        }
        
        return grouped
            .map { DaySection(date: $0.key, items: $0.value.sorted { $0.timestamp > $1.timestamp }) }
            .sorted { $0.date > $1.date }
    }
    
    private func sectionTitle(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }
}

struct DaySection {
    let date: Date
    let items: [MindEntry]
}
