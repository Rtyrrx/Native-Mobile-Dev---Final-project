import Foundation
import SwiftData

@Model
final class MindEntry {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    
    var rawTranscript: String
    
    var title: String
    var summary: String
    
    var primaryEmotion: String
    var emotionIntensity: Int
    
    var growthArea: String
    var entryType: String
    
    var topicsJSON: String
    var peopleJSON: String
    
    var loopKey: String
    
    var insight: String?
    var suggestedAction: String?
    
    var roomId: UUID?
    var parentId: UUID?

    var topics: [String] {
        get { Self.decodeArray(from: topicsJSON) }
        set { topicsJSON = Self.encodeArray(newValue) }
    }
    
    var people: [String] {
        get { Self.decodeArray(from: peopleJSON) }
        set { peopleJSON = Self.encodeArray(newValue) }
    }
    
    init(
        timestamp: Date = Date(),
        rawTranscript: String,
        title: String,
        summary: String,
        primaryEmotion: String,
        emotionIntensity: Int,
        growthArea: String,
        entryType: String,
        topics: [String] = [],
        people: [String] = [],
        loopKey: String = "",
        insight: String? = nil,
        suggestedAction: String? = nil,
        roomId: UUID? = nil,
        parentId: UUID? = nil
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.rawTranscript = rawTranscript
        
        self.title = title
        self.summary = summary
        
        self.primaryEmotion = primaryEmotion
        self.emotionIntensity = emotionIntensity
        
        self.growthArea = growthArea
        self.entryType = entryType
        
        self.topicsJSON = Self.encodeArray(topics)
        self.peopleJSON = Self.encodeArray(people)
        
        self.loopKey = loopKey
        
        self.insight = insight
        self.suggestedAction = suggestedAction
        
        self.roomId = roomId
        self.parentId = parentId
    }
    
    private static func decodeArray(from json: String) -> [String] {
        guard let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
    
    private static func encodeArray(_ arr: [String]) -> String {
        let data = (try? JSONEncoder().encode(arr)) ?? Data("[]".utf8)
        return String(data: data, encoding: .utf8) ?? "[]"
    }
}
