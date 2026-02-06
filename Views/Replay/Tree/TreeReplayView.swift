import SwiftUI

enum TreeMode: String, CaseIterable, Identifiable {
    case hierarchy = "Hierarchy"
    case day = "Day"
    case emotion = "Emotion"
    case area = "Area"
    var id: String { rawValue }
}

struct TreeReplayView: View {
    
    let entries: [MindEntry]
    @State var mode: TreeMode = .hierarchy
    
    @State private var pan: CGSize = .zero
    @State private var lastPan: CGSize = .zero
    
    @State private var zoom: CGFloat = 1.0
    @State private var lastZoom: CGFloat = 1.0
    
    @State private var selectedEntry: MindEntry?
    @State private var showDetailSheet: Bool = false
    
    private let nodeSize = CGSize(width: 230, height: 78)
    
    private let clusterRadius: CGFloat = 240
    private let clusterSpacingX: CGFloat = 820
    private let clusterSpacingY: CGFloat = 620
    private let gridCols: Int = 3

    private let treeXGap: CGFloat = 280
    private let treeYGap: CGFloat = 160
    private let rootsGapY: CGFloat = 240
    
    private let minZoom: CGFloat = 0.12
    private let maxZoom: CGFloat = 12.0
    
    var body: some View {
        VStack(spacing: 10) {
            
            Picker("Mode", selection: $mode) {
                ForEach(TreeMode.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            GeometryReader { geo in
                let graph = buildGraph()
                
                ZStack {
                    Canvas { context, size in
                        context.translateBy(
                            x: size.width / 2 + pan.width,
                            y: size.height / 2 + pan.height
                        )
                        context.scaleBy(x: zoom, y: zoom)
                        
                        drawClusterLabels(context: &context, graph: graph)
                        drawEdges(context: &context, graph: graph)
                        drawNodes(context: &context, graph: graph)
                    }
                    .background(Color.black)
                    
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            SpatialTapGesture()
                                .onEnded { value in
                                    if let entry = hitTest(
                                        tapPoint: value.location,
                                        canvasSize: geo.size,
                                        graph: graph
                                    ) {
                                        selectedEntry = entry
                                        showDetailSheet = true
                                    }
                                }
                        )
                }
                .highPriorityGesture(panGesture)
                .simultaneousGesture(zoomGesture)
            }
        }
        .sheet(isPresented: $showDetailSheet) {
            if let entry = selectedEntry {
                MindEntryDetailView(entry: entry)
            } else {
                Text("No entry selected")
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
    }
    
    // MARK: - Gestures
    
    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .local)
            .onChanged { value in
                pan = CGSize(
                    width: lastPan.width + value.translation.width,
                    height: lastPan.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastPan = pan
            }
    }
    
    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                zoom = clamp(lastZoom * value, min: minZoom, max: maxZoom)
            }
            .onEnded { _ in
                lastZoom = zoom
            }
    }
    
    private func clamp(_ v: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        Swift.max(min, Swift.min(max, v))
    }
    
    // MARK: - Graph build
    
    private func buildGraph() -> Graph {
        let nodes = entries.map { GraphNode(id: $0.id.uuidString, entry: $0) }
        let byId: [String: GraphNode] = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        
        if mode == .hierarchy {
            var children: [String: [GraphNode]] = [:]
            var roots: [GraphNode] = []
            
            for n in nodes {
                if let pid = n.entry.parentId?.uuidString, byId[pid] != nil {
                    children[pid, default: []].append(n)
                } else {
                    roots.append(n)
                }
            }
            
            for (k, list) in children {
                children[k] = list.sorted { $0.entry.timestamp < $1.entry.timestamp }
            }
            roots = roots.sorted { $0.entry.timestamp < $1.entry.timestamp }
            
            var edges: [GraphEdge] = []
            for n in nodes {
                if let pid = n.entry.parentId?.uuidString, byId[pid] != nil {
                    edges.append(GraphEdge(from: pid, to: n.id))
                }
            }
            
            var positions: [String: CGPoint] = [:]
            
            var rootTopY: CGFloat = 0
            for root in roots {
                let _ = treeWidth(rootId: root.id, children: children)
                
                layoutTree(
                    rootId: root.id,
                    depth: 0,
                    startX: 0,
                    topY: rootTopY,
                    children: children,
                    positions: &positions
                )
                
                let h = treeHeight(rootId: root.id, children: children)
                rootTopY += CGFloat(h) * treeYGap + rootsGapY
            }
            
            return Graph(
                nodes: nodes,
                edges: edges,
                positions: positions,
                clusters: []
            )
        }
        
        let groups: [(key: String, items: [GraphNode])] = {
            switch mode {
            case .day:
                let f = DateFormatter()
                f.dateStyle = .medium
                let dict = Dictionary(grouping: nodes) { f.string(from: $0.entry.timestamp) }
                return dict.map { ($0.key, $0.value) }.sorted { $0.key > $1.key }
                
            case .emotion:
                let dict = Dictionary(grouping: nodes) { $0.entry.primaryEmotion.lowercased() }
                return dict.map { ($0.key, $0.value) }.sorted { $0.key < $1.key }
                
            case .area:
                let dict = Dictionary(grouping: nodes) { $0.entry.growthArea.lowercased() }
                return dict.map { ($0.key, $0.value) }.sorted { $0.key < $1.key }
                
            case .hierarchy:
                return []
            }
        }()
        
        var positions: [String: CGPoint] = [:]
        var edges: [GraphEdge] = []
        var clusters: [Cluster] = []
        
        for (gi, group) in groups.enumerated() {
            let col = gi % gridCols
            let row = gi / gridCols
            
            let center = CGPoint(
                x: CGFloat(col) * clusterSpacingX - clusterSpacingX,
                y: CGFloat(row) * clusterSpacingY - clusterSpacingY
            )
            
            clusters.append(Cluster(key: group.key, center: center))
            
            let sortedItems = group.items.sorted { $0.entry.timestamp > $1.entry.timestamp }
            let count = sortedItems.count
            guard count > 0 else { continue }
            
            for (i, node) in sortedItems.enumerated() {
                let angle = (2.0 * Double.pi / Double(max(count, 1))) * Double(i)
                let x = center.x + cos(angle) * clusterRadius
                let y = center.y + sin(angle) * clusterRadius
                positions[node.id] = CGPoint(x: x, y: y)
                
                if i > 0 {
                    edges.append(GraphEdge(from: sortedItems[i - 1].id, to: node.id))
                }
            }
            
            if count >= 3 {
                let hub = sortedItems[0]
                for i in 1..<min(count, 6) {
                    edges.append(GraphEdge(from: hub.id, to: sortedItems[i].id))
                }
            }
        }
        
        return Graph(nodes: nodes, edges: edges, positions: positions, clusters: clusters)
    }
    
    // MARK: - Hierarchy layout helpers
    
    private func treeWidth(rootId: String, children: [String: [GraphNode]]) -> CGFloat {
        let kids = children[rootId] ?? []
        if kids.isEmpty { return treeXGap }
        return kids.map { treeWidth(rootId: $0.id, children: children) }.reduce(0, +)
    }
    
    private func treeHeight(rootId: String, children: [String: [GraphNode]]) -> Int {
        let kids = children[rootId] ?? []
        if kids.isEmpty { return 1 }
        let maxChild = kids.map { treeHeight(rootId: $0.id, children: children) }.max() ?? 1
        return 1 + maxChild
    }
    
    private func layoutTree(
        rootId: String,
        depth: Int,
        startX: CGFloat,
        topY: CGFloat,
        children: [String: [GraphNode]],
        positions: inout [String: CGPoint]
    ) {
        let kids = children[rootId] ?? []
        let myY = topY + CGFloat(depth) * treeYGap
        
        if kids.isEmpty {
            positions[rootId] = CGPoint(x: startX + treeXGap / 2, y: myY)
            return
        }
        
        var cursorX = startX
        var centers: [CGFloat] = []
        
        for child in kids {
            let w = treeWidth(rootId: child.id, children: children)
            
            layoutTree(
                rootId: child.id,
                depth: depth + 1,
                startX: cursorX,
                topY: topY,
                children: children,
                positions: &positions
            )
            
            centers.append(cursorX + w / 2)
            cursorX += w
        }
        
        let parentX = (centers.first! + centers.last!) / 2
        positions[rootId] = CGPoint(x: parentX, y: myY)
    }
    
    // MARK: - Draw
    
    private func drawClusterLabels(context: inout GraphicsContext, graph: Graph) {
        guard mode != .hierarchy else { return }
        
        let labelYOffset = clusterRadius + (nodeSize.height / 2) + 16
        
        for c in graph.clusters {
            let label = Text(c.key.capitalized)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundColor(.white.opacity(0.55))
            
            context.draw(
                label,
                at: CGPoint(x: c.center.x, y: c.center.y - labelYOffset),
                anchor: .center
            )
        }
    }
    
    private func drawEdges(context: inout GraphicsContext, graph: Graph) {
        for e in graph.edges {
            guard let a = graph.positions[e.from], let b = graph.positions[e.to] else { continue }
            
            var path = Path()
            path.move(to: a)
            
            if mode == .hierarchy {
                let midY = a.y + (b.y - a.y) * 0.35
                let c1 = CGPoint(x: a.x, y: midY)
                let c2 = CGPoint(x: b.x, y: midY)
                path.addCurve(to: b, control1: c1, control2: c2)
            } else {
                let midX = (a.x + b.x) / 2
                let c1 = CGPoint(x: midX, y: a.y)
                let c2 = CGPoint(x: midX, y: b.y)
                path.addCurve(to: b, control1: c1, control2: c2)
            }
            
            context.stroke(path, with: .color(.white.opacity(0.18)), lineWidth: 1.6)
        }
    }
    
    private func drawNodes(context: inout GraphicsContext, graph: Graph) {
        for node in graph.nodes {
            guard let p = graph.positions[node.id] else { continue }
            drawNode(context: &context, center: p, entry: node.entry)
        }
    }
    
    private func drawNode(context: inout GraphicsContext, center: CGPoint, entry: MindEntry) {
        let w = nodeSize.width
        let h = nodeSize.height
        
        let rect = CGRect(x: center.x - w/2, y: center.y - h/2, width: w, height: h)
        let shape = RoundedRectangle(cornerRadius: 14)
        let path = shape.path(in: rect)
        
        context.fill(path, with: .color(.white.opacity(0.06)))
        context.stroke(path, with: .color(.white.opacity(0.18)), lineWidth: 1)
        
        let titleLines = wrapTitle(entry.title, maxCharsPerLine: 24, maxLines: 2)
        let titleLine1 = titleLines.first ?? ""
        let titleLine2 = titleLines.count > 1 ? titleLines[1] : nil
        
        let title1 = Text(titleLine1)
            .font(.system(size: 13.6, weight: .semibold))
            .foregroundColor(.white)
        
        context.draw(title1,
                     at: CGPoint(x: rect.minX + 12, y: rect.minY + 20),
                     anchor: .leading)
        
        if let titleLine2 {
            let title2 = Text(titleLine2)
                .font(.system(size: 13.6, weight: .semibold))
                .foregroundColor(.white.opacity(0.92))
            
            context.draw(title2,
                         at: CGPoint(x: rect.minX + 12, y: rect.minY + 38),
                         anchor: .leading)
        }
        
        let emotion = entry.primaryEmotion.lowercased()
        let area = entry.growthArea.lowercased()
        let metaText = "\(truncate(emotion, max: 12)) • \(truncate(area, max: 14)) • \(entry.emotionIntensity)/5"
        
        let meta = Text(metaText)
            .font(.system(size: 11))
            .foregroundColor(.white.opacity(0.65))
        
        context.draw(meta,
                     at: CGPoint(x: rect.minX + 12, y: rect.maxY - 16),
                     anchor: .leading)
    }
    
    // MARK: - Hit testing
    
    private func hitTest(tapPoint: CGPoint, canvasSize: CGSize, graph: Graph) -> MindEntry? {
        let x = (tapPoint.x - canvasSize.width / 2 - pan.width) / zoom
        let y = (tapPoint.y - canvasSize.height / 2 - pan.height) / zoom
        let p = CGPoint(x: x, y: y)
        
        let w = nodeSize.width
        let h = nodeSize.height
        
        for node in graph.nodes.reversed() {
            guard let c = graph.positions[node.id] else { continue }
            let rect = CGRect(x: c.x - w/2, y: c.y - h/2, width: w, height: h)
            if rect.contains(p) { return node.entry }
        }
        return nil
    }
    
    // MARK: - Text utils
    
    private func truncate(_ s: String, max: Int) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > max else { return trimmed }
        let idx = trimmed.index(trimmed.startIndex, offsetBy: max)
        return String(trimmed[..<idx]) + "…"
    }
    
    private func wrapTitle(_ title: String, maxCharsPerLine: Int, maxLines: Int) -> [String] {
        let words = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .map(String.init)
        
        if words.isEmpty { return [""] }
        
        var lines: [String] = []
        var current = ""
        
        for w in words {
            let candidate = current.isEmpty ? w : "\(current) \(w)"
            if candidate.count <= maxCharsPerLine {
                current = candidate
            } else {
                if !current.isEmpty { lines.append(current) }
                current = w
                if lines.count == maxLines - 1 { break }
            }
        }
        
        if lines.count < maxLines, !current.isEmpty {
            lines.append(current)
        }
        
        if lines.count > maxLines {
            lines = Array(lines.prefix(maxLines))
        }
        
        if let last = lines.last, last.count > maxCharsPerLine {
            lines[lines.count - 1] = truncate(last, max: maxCharsPerLine)
        }
        
        let combined = lines.joined(separator: " ")
        if combined.count < title.count {
            lines[lines.count - 1] = truncate(lines[lines.count - 1], max: maxCharsPerLine)
        }
        
        return lines
    }
}

// MARK: - Graph types

struct Graph {
    let nodes: [GraphNode]
    let edges: [GraphEdge]
    let positions: [String: CGPoint]
    let clusters: [Cluster]
}

struct GraphNode {
    let id: String
    let entry: MindEntry
}

struct GraphEdge {
    let from: String
    let to: String
}

struct Cluster {
    let key: String
    let center: CGPoint
}
