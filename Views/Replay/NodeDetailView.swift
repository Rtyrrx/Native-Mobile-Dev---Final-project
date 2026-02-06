import SwiftUI
import SwiftData

struct NodeDetailView: View {
    @Environment(\.modelContext) private var context
    
    let node: MindEntry
    
    @Query(sort: \MindEntry.timestamp, order: .forward)
    private var all: [MindEntry]
    
    @State private var showAddChild = false
    
    private var children: [MindEntry] {
        all
            .filter { $0.parentId == node.id }
            .sorted { $0.timestamp < $1.timestamp }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                
                Text(node.title)
                    .font(.system(size: 22, weight: .semibold))
                
                Text(node.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                
                Text(node.summary)
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.92))
                
                infoPills
                
                if let action = node.suggestedAction, !action.isEmpty {
                    Divider().opacity(0.2)
                    Text("Suggested action")
                        .font(.system(size: 14, weight: .semibold))
                    Text(action)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                
                Divider().opacity(0.2)
                
                HStack {
                    Text("Children (\(children.count))")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Button("Add child node") {
                        showAddChild = true
                    }
                    .font(.system(size: 13, weight: .semibold))
                }
                
                if children.isEmpty {
                    Text("No children yet. Add one and it will appear connected in the tree.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                } else {
                    VStack(spacing: 10) {
                        ForEach(children) { c in
                            NavigationLink {
                                NodeDetailView(node: c)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(c.title)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    Text(c.summary)
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                .padding(12)
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 6)
                }
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
        .foregroundStyle(.white)
        .navigationTitle("Node")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showAddChild) {
            AddChildView(parent: node)
        }
    }
    
    private var infoPills: some View {
        HStack(spacing: 10) {
            pill(node.primaryEmotion)
            pill("\(node.emotionIntensity)/5")
            pill(node.growthArea)
            pill(node.entryType)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.white.opacity(0.85))
    }
    
    private func pill(_ t: String) -> some View {
        Text(t.isEmpty ? "—" : t)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.06))
            .clipShape(Capsule())
    }
}
