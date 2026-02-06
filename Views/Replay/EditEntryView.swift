import SwiftUI
import SwiftData

struct EditEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    @Bindable var entry: MindEntry
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Title", text: $entry.title)
                }
                Section("Summary") {
                    TextEditor(text: $entry.summary)
                        .frame(minHeight: 140)
                }
                Section("Tags") {
                    TextField("Loop Key", text: $entry.loopKey)
                    TextField("Emotion", text: $entry.primaryEmotion)
                    TextField("Area", text: $entry.growthArea)
                    TextField("Type", text: $entry.entryType)
                }
            }
            .navigationTitle("Edit")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        do {
                            try context.save()
                            dismiss()
                        } catch {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}
