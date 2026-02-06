import SwiftUI

struct MindEntryDetailView: View {
    
    let entry: MindEntry
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                
                Text(entry.title)
                    .font(.largeTitle.bold())
                
                Text(entry.summary)
                    .font(.body)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Emotion: \(entry.primaryEmotion)")
                    Text("Intensity: \(entry.emotionIntensity)/5")
                    Text("Growth Area: \(entry.growthArea)")
                }
                .font(.subheadline)
                
                if let insight = entry.insight {
                    Divider()
                    Text("Insight")
                        .font(.headline)
                    Text(insight)
                }
                
                if let action = entry.suggestedAction {
                    Divider()
                    Text("Suggested Action")
                        .font(.headline)
                    Text(action)
                }
                
                Divider()
                
                Text("Raw Thought")
                    .font(.headline)
                Text(entry.rawTranscript)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}
