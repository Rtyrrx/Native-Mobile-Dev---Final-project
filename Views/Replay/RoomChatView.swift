import SwiftUI
import SwiftData

struct RoomChatView: View {
    let room: Room
    
    @Environment(\.modelContext) private var context
    
    @Query(sort: \MindEntry.timestamp, order: .forward)
    private var allEntries: [MindEntry]
    
    @State private var inputText: String = ""
    @State private var isSending = false
    @State private var errorText: String?
    
    private var roomEntries: [MindEntry] {
        allEntries.filter { $0.roomId == room.id }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            // MARK: Messages
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(roomEntries) { entry in
                            NavigationLink {
                                NodeDetailView(node: entry)
                            } label: {
                                messageBubble(entry)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
            
            Divider().opacity(0.2)
            
            // MARK: Input
            VStack(spacing: 8) {
                if let errorText {
                    Text(errorText)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                HStack(spacing: 10) {
                    TextEditor(text: $inputText)
                        .frame(minHeight: 44, maxHeight: 90)
                        .padding(8)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    
                    Button {
                        Task { await send() }
                    } label: {
                        if isSending {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 16, weight: .bold))
                        }
                    }
                    .frame(width: 44, height: 44)
                    .background(Color.white)
                    .clipShape(Circle())
                    .disabled(isSending || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
            .background(Color.black)
        }
        .background(Color.black.ignoresSafeArea())
        .foregroundStyle(.white)
        .navigationTitle(room.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    RoomTreeView(room: room)
                } label: {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                }
            }
        }
    }
    
    // MARK: - Message bubble
    private func messageBubble(_ entry: MindEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.title)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
            
            Text(entry.summary)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineLimit(3)
            
            HStack(spacing: 8) {
                Text(entry.primaryEmotion)
                Text(entry.growthArea)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Send
    private func send() async {
        errorText = nil
        
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        isSending = true
        defer { isSending = false }
        
        do {
            let ai = AIAnalysisService()
            let result = try await ai.analyze(text: text)
            
            let entry = MindEntry(
                rawTranscript: text,
                title: result.title,
                summary: result.summary,
                primaryEmotion: result.primaryEmotion,
                emotionIntensity: result.emotionIntensity,
                growthArea: result.growthArea,
                entryType: result.entryType,
                topics: result.topics,
                people: result.people,
                loopKey: result.loopKey,
                insight: result.insight,
                suggestedAction: result.suggestedAction,
                roomId: room.id,
                parentId: nil
            )
            
            await MainActor.run {
                context.insert(entry)
                inputText = ""
            }
            
            try context.save()
            
        } catch let caught {
            await MainActor.run {
                errorText = "Send failed: \(caught.localizedDescription)"
            }
        }
    }
}
