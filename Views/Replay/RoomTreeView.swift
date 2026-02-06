import SwiftUI
import SwiftData

struct RoomTreeView: View {
    let room: Room
    
    @Query(sort: \MindEntry.timestamp, order: .forward)
    private var all: [MindEntry]
    
    private var entries: [MindEntry] {
        all.filter { $0.roomId == room.id }
    }
    
    var body: some View {
        TreeCanvas(entries: entries)
            .navigationTitle("Tree")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.black.ignoresSafeArea())
    }
}

// MARK: - Main Canvas
private struct TreeCanvas: View {
    let entries: [MindEntry]
    
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    var body: some View {
        let graph = TreeGraph(entries: entries)
        
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()
                
                if graph.nodes.isEmpty {
                    Text("No nodes yet")
                        .foregroundStyle(.secondary)
                } else {
                    ZStack {
                        ForEach(graph.edges) { edge in
                            if let a = graph.pos[edge.from], let b = graph.pos[edge.to] {
                                TreeEdgeLine(from: a, to: b)
                            }
                        }
                        ForEach(graph.nodes) { node in
                            let p = graph.pos[node.id]!
                            
                            NavigationLink {
                                NodeDetailView(node: node)
                            } label: {
                                TreeNode(node: node)
                            }
                            .buttonStyle(.plain)
                            .position(
                                x: p.x + geo.size.width / 2 + offset.width,
                                y: p.y + geo.size.height / 2 + offset.height
                            )
                        }
                    }
                    .scaleEffect(scale)
                    .gesture(panGesture.simultaneously(with: zoomGesture))
                }
            }
        }
    }
    
    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { v in
                offset = CGSize(
                    width: lastOffset.width + v.translation.width,
                    height: lastOffset.height + v.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }
    
    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { v in
                let newScale = lastScale * v
                scale = min(max(newScale, 0.25), 3.0)
            }
            .onEnded { _ in
                lastScale = scale
            }
    }
}


private struct TreeEdge: Identifiable {
    let id = UUID()
    let from: UUID
    let to: UUID
}

private struct TreeGraph {
    let nodes: [MindEntry]
    let edges: [TreeEdge]
    let pos: [UUID: CGPoint]
    
    init(entries: [MindEntry]) {
        self.nodes = entries
        
        let dict = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
        
        var children: [UUID: [MindEntry]] = [:]
        var roots: [MindEntry] = []
        
        for node in entries {
            if let pid = node.parentId, dict[pid] != nil {
                children[pid, default: []].append(node)
            } else {
                roots.append(node)
            }
        }
        
        for (pid, list) in children {
            children[pid] = list.sorted { $0.timestamp < $1.timestamp }
        }
        
        roots = roots.sorted { $0.timestamp < $1.timestamp }

        var ee: [TreeEdge] = []
        for n in entries {
            if let pid = n.parentId, dict[pid] != nil {
                ee.append(TreeEdge(from: pid, to: n.id))
            }
        }
        self.edges = ee
        
        let xGap: CGFloat = 280
        let yGap: CGFloat = 160
        
        var pos: [UUID: CGPoint] = [:]
        
        var currentY: CGFloat = 0
        
        for root in roots {
            TreeGraph.layout(rootId: root.id,
                   depth: 0,
                   startX: 0,
                   topY: currentY,
                   children: children,
                   pos: &pos,
                   xGap: xGap,
                   yGap: yGap)
            
            let h = TreeGraph.treeHeight(rootId: root.id, children: children)
            currentY += CGFloat(h) * yGap + 220
        }
        
        self.pos = pos
    }
    
    // MARK: Recursion
    
    private static func treeWidth(rootId: UUID, children: [UUID: [MindEntry]], xGap: CGFloat) -> CGFloat {
        let kids = children[rootId] ?? []
        if kids.isEmpty { return xGap }
        return kids.map { treeWidth(rootId: $0.id, children: children, xGap: xGap) }.reduce(0, +)
    }
    
    private static func treeHeight(rootId: UUID, children: [UUID: [MindEntry]]) -> Int {
        let kids = children[rootId] ?? []
        if kids.isEmpty { return 1 }
        return 1 + kids.map { treeHeight(rootId: $0.id, children: children) }.max()!
    }
    
    private static func layout(
        rootId: UUID,
        depth: Int,
        startX: CGFloat,
        topY: CGFloat,
        children: [UUID: [MindEntry]],
        pos: inout [UUID: CGPoint],
        xGap: CGFloat,
        yGap: CGFloat
    ) {
        let kids = children[rootId] ?? []
        let myY = topY + CGFloat(depth) * yGap
        
        if kids.isEmpty {
            pos[rootId] = CGPoint(x: startX + xGap/2, y: myY)
            return
        }
        
        var cursor = startX
        var centers: [CGFloat] = []
        
        for child in kids {
            let w = treeWidth(rootId: child.id, children: children, xGap: xGap)
            layout(
                rootId: child.id,
                depth: depth + 1,
                startX: cursor,
                topY: topY,
                children: children,
                pos: &pos,
                xGap: xGap,
                yGap: yGap
            )
            centers.append(cursor + w/2)
            cursor += w
        }
        
        let parentX = (centers.first! + centers.last!) / 2
        pos[rootId] = CGPoint(x: parentX, y: myY)
    }
}

private struct TreeNode: View {
    let node: MindEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(node.title)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
            Text(node.summary)
                .font(.system(size: 12))
                .lineLimit(3)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(width: 220, alignment: .leading)
        .background(Color.white.opacity(0.07))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.13)))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct TreeEdgeLine: View {
    let from: CGPoint
    let to: CGPoint
    
    var body: some View {
        Path { path in
            let midY = from.y + (to.y - from.y) * 0.35
            let c1 = CGPoint(x: from.x, y: midY)
            let c2 = CGPoint(x: to.x,   y: midY)
            
            path.move(to: from)
            path.addCurve(to: to, control1: c1, control2: c2)
        }
        .stroke(Color.white.opacity(0.22), lineWidth: 2)
    }
}
