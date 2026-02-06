import SwiftUI

struct MindEntryRow: View {
    
    let entry: MindEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            
            Text(entry.title)
                .font(.headline)
            
            Text(entry.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            
            HStack {
                Text(entry.primaryEmotion.capitalized)
                Spacer()
                Text("Intensity \(entry.emotionIntensity)/5")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}
	
