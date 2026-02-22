import Foundation
import SwiftData

// MARK: - Expense Category
enum ExpenseCategory: String, Codable, CaseIterable {
    case food = "Food"
    case transport = "Transport"
    case bills = "Bills"
    case shopping = "Shopping"
    case health = "Health"
    case entertainment = "Entertainment"
    case other = "Other"

    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .transport: return "car.fill"
        case .bills: return "doc.text.fill"
        case .shopping: return "bag.fill"
        case .health: return "heart.fill"
        case .entertainment: return "gamecontroller.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .food: return "orange"
        case .transport: return "blue"
        case .bills: return "purple"
        case .shopping: return "pink"
        case .health: return "red"
        case .entertainment: return "green"
        case .other: return "gray"
        }
    }
}

// MARK: - Expense Model
@Model
final class Expense {
    var id: UUID
    var date: Date
    var amount: Double
    var categoryRaw: String
    var customCategoryId: UUID?
    var note: String

    var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var isCustomCategory: Bool {
        customCategoryId != nil
    }

    init(
        id: UUID = UUID(),
        date: Date = .now,
        amount: Double = 0,
        category: ExpenseCategory = .other,
        customCategoryId: UUID? = nil,
        note: String = ""
    ) {
        self.id = id
        self.date = date
        self.amount = amount
        self.categoryRaw = category.rawValue
        self.customCategoryId = customCategoryId
        self.note = note
    }

    // Convenience init for custom category
    init(
        id: UUID = UUID(),
        date: Date = .now,
        amount: Double = 0,
        customCategory: CustomCategory,
        note: String = ""
    ) {
        self.id = id
        self.date = date
        self.amount = amount
        self.categoryRaw = customCategory.name
        self.customCategoryId = customCategory.id
        self.note = note
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    var formattedFullDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}
