import Foundation
import SwiftData

@Model
final class Room {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var title: String
    
    init(title: String, createdAt: Date = Date()) {
        self.id = UUID()
        self.createdAt = createdAt
        self.title = title
    }
}

