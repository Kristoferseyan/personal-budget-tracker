import Foundation
import SwiftUI
import SwiftData

enum WishlistPriority: Int, Codable {
    case none = 0
    case high = 1
    case medium = 2
    case low = 3
    case skip = 4

    var label: String {
        switch self {
        case .none: return ""
        case .high: return "Buy First"
        case .medium: return "Can Wait"
        case .low: return "Low Priority"
        case .skip: return "Skip"
        }
    }

    var color: Color {
        switch self {
        case .none: return .secondary
        case .high: return .green
        case .medium: return .blue
        case .low: return .orange
        case .skip: return .red
        }
    }

    var icon: String {
        switch self {
        case .none: return "minus.circle"
        case .high: return "1.circle.fill"
        case .medium: return "2.circle.fill"
        case .low: return "3.circle.fill"
        case .skip: return "xmark.circle.fill"
        }
    }
}

@Model
final class WishlistItem {
    var id: UUID
    var name: String
    var estimatedPrice: Double
    var notes: String
    var isPurchased: Bool
    var dateAdded: Date
    var priorityValue: Int

    var priority: WishlistPriority {
        get { WishlistPriority(rawValue: priorityValue) ?? .none }
        set { priorityValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        estimatedPrice: Double,
        notes: String = "",
        isPurchased: Bool = false,
        dateAdded: Date = .now,
        priority: WishlistPriority = .none
    ) {
        self.id = id
        self.name = name
        self.estimatedPrice = estimatedPrice
        self.notes = notes
        self.isPurchased = isPurchased
        self.dateAdded = dateAdded
        self.priorityValue = priority.rawValue
    }
}
