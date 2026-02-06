//
//  Filters.swift
//  LifeReplay
//
//  Created by Madias Bek on 08.02.2026.
//

import Foundation

enum TimeFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case today = "Today"
    case last7 = "Last 7"
    case last30 = "Last 30"
    
    var id: String { rawValue }
}

enum GrowthFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case emotional = "emotional"
    case professional = "professional"
    case personal = "personal"
    case relationships = "relationships"
    case health = "health"
    case reflection = "reflection"
    
    var id: String { rawValue }
}
