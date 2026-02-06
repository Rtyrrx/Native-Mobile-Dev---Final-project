import SwiftUI
import SwiftData

struct RoomsView: View {
    @Environment(\.modelContext) private var context
    
    @Query(sort: \Room.createdAt, order: .reverse)
    private var rooms: [Room]
    
    @Query(sort: \MindEntry.timestamp, order: .reverse)
    private var entries: [MindEntry]
    
    var body: some View {
        NavigationStack {
            List {
                if !rooms.isEmpty {
                    Section("Rooms") {
                        ForEach(rooms) { room in
                            NavigationLink {
                                RoomChatView(room: room)
                            } label: {
                                roomRow(room)
                            }
                        }
                    }
                }
                
                let legacyRoots = entries.filter { $0.roomId == nil && $0.parentId == nil }
                if !legacyRoots.isEmpty {
                    Section("Legacy moments") {
                        ForEach(legacyRoots) { e in
                            NavigationLink {
                                NodeDetailView(node: e)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(e.title).font(.system(size: 15, weight: .semibold))
                                    Text(e.summary).font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(2)
                                }
                                .padding(.vertical, 6)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Replay")
        }
    }
    
    private func roomRow(_ room: Room) -> some View {
        let roomEntries = entries.filter { $0.roomId == room.id }
        let root = roomEntries.first(where: { $0.parentId == nil }) ?? roomEntries.sorted(by: { $0.timestamp < $1.timestamp }).first
        
        return VStack(alignment: .leading, spacing: 6) {
            Text(room.title)
                .font(.system(size: 15, weight: .semibold))
            if let root {
                Text(root.summary)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else {
                Text("Empty room")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}
