import SwiftUI

struct LegacyMomentDetailView: View {
    let entry: MindEntry
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(entry.title).font(.system(size: 22, weight: .semibold))
                Text(entry.timestamp.formatted()).font(.system(size: 12)).foregroundStyle(.secondary)
                
                Text(entry.summary).font(.system(size: 15))
                
                if let action = entry.suggestedAction, !action.isEmpty {
                    Divider().opacity(0.2)
                    Text("Suggested action").font(.system(size: 14, weight: .semibold))
                    Text(action).font(.system(size: 14)).foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
        .foregroundStyle(.white)
        .navigationTitle("Moment")
        .navigationBarTitleDisplayMode(.inline)
    }
}
