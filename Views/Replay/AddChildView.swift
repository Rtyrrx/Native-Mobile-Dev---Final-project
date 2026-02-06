import SwiftUI
import SwiftData

struct AddChildView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    let parent: MindEntry
    
    @State private var text: String = ""
    @State private var isSaving = false
    @State private var errorText: String?
    
    private let ai = AIAnalysisService()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Parent")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(parent.title)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                TextEditor(text: $text)
                    .frame(minHeight: 160)
                    .padding(10)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                
                if let errorText {
                    Text(errorText)
                        .font(.system(size: 12))
                        .foregroundStyle(.red.opacity(0.95))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Button {
                    Task { await saveChild() }
                } label: {
                    HStack {
                        if isSaving { ProgressView().tint(.white) }
                        Text(isSaving ? "Saving…" : "Analyze & Save Child")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .disabled(isSaving || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1)
                
                Spacer()
            }
            .padding()
            .background(Color.black.ignoresSafeArea())
            .foregroundStyle(.white)
            .navigationTitle("Add Child")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
    
    private func saveChild() async {
        errorText = nil
        
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        
        isSaving = true
        defer { isSaving = false }
        
        do {
            let contextText = """
PARENT_NODE:
Title: \(parent.title)
Summary: \(parent.summary)

CHILD_NODE_INPUT:

Task: Return JSON only for the CHILD_NODE_INPUT, but keep PARENT_NODE context.
"""
            let result = try await ai.analyze(text: contextText)
            
            let entry = MindEntry(
                rawTranscript: input,
                title: result.title,
                summary: result.summary,
                primaryEmotion: result.primaryEmotion,
                emotionIntensity: max(1, min(result.emotionIntensity, 5)),
                growthArea: result.growthArea,
                entryType: result.entryType,
                topics: result.topics,
                people: result.people,
                loopKey: result.loopKey,
                insight: result.insight,
                suggestedAction: result.suggestedAction,
                roomId: parent.roomId,
                parentId: parent.id         
            )
            
            await MainActor.run {
                context.insert(entry)
            }
            try context.save()
            
            await MainActor.run {
                dismiss()
            }
            
        } catch let caught {
            await MainActor.run {
                errorText = "Save failed: \(caught.localizedDescription)"
            }
        }
    }
}
