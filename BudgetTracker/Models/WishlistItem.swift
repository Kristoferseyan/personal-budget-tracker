import Foundation
import SwiftData

@Model
final class WishlistItem {
    var id: UUID
    var name: String
    var estimatedPrice: Double
    var notes: String
    var isPurchased: Bool
    var dateAdded: Date

    init(
        id: UUID = UUID(),
        name: String,
        estimatedPrice: Double,
        notes: String = "",
        isPurchased: Bool = false,
        dateAdded: Date = .now
    ) {
        self.id = id
        self.name = name
        self.estimatedPrice = estimatedPrice
        self.notes = notes
        self.isPurchased = isPurchased
        self.dateAdded = dateAdded
    }
}
