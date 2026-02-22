import Foundation
import SwiftData

@Model
final class CustomCategory {
    var id: UUID
    var name: String
    var icon: String
    var colorName: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "tag.fill",
        colorName: String = "blue",
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorName = colorName
        self.createdAt = createdAt
    }
}

// MARK: - Available Icons for Selection
enum CategoryIcons {
    static let all: [(name: String, icon: String)] = [
        // Food & Drink
        ("Fork & Knife", "fork.knife"),
        ("Cup", "cup.and.saucer.fill"),
        ("Cart", "cart.fill"),
        ("Basket", "basket.fill"),

        // Transport
        ("Car", "car.fill"),
        ("Bus", "bus.fill"),
        ("Bicycle", "bicycle"),
        ("Fuel", "fuelpump.fill"),

        // Home & Bills
        ("House", "house.fill"),
        ("Lightbulb", "lightbulb.fill"),
        ("Wifi", "wifi"),
        ("Drop", "drop.fill"),

        // Shopping
        ("Bag", "bag.fill"),
        ("Gift", "gift.fill"),
        ("Tag", "tag.fill"),
        ("Creditcard", "creditcard.fill"),

        // Health & Fitness
        ("Heart", "heart.fill"),
        ("Pills", "pills.fill"),
        ("Cross", "cross.fill"),
        ("Figure Walk", "figure.walk"),

        // Entertainment
        ("Gamecontroller", "gamecontroller.fill"),
        ("TV", "tv.fill"),
        ("Music", "music.note"),
        ("Film", "film.fill"),

        // Tech & Work
        ("Phone", "iphone"),
        ("Laptop", "laptopcomputer"),
        ("Briefcase", "briefcase.fill"),
        ("Book", "book.fill"),

        // Pets & Animals
        ("Pawprint", "pawprint.fill"),
        ("Hare", "hare.fill"),
        ("Fish", "fish.fill"),
        ("Leaf", "leaf.fill"),

        // Other
        ("Star", "star.fill"),
        ("Bolt", "bolt.fill"),
        ("Wrench", "wrench.fill"),
        ("Ellipsis", "ellipsis.circle.fill"),
    ]
}

// MARK: - Available Colors
enum CategoryColors {
    static let all: [(name: String, display: String)] = [
        ("blue", "Blue"),
        ("green", "Green"),
        ("orange", "Orange"),
        ("red", "Red"),
        ("purple", "Purple"),
        ("pink", "Pink"),
        ("yellow", "Yellow"),
        ("teal", "Teal"),
        ("indigo", "Indigo"),
        ("brown", "Brown"),
    ]
}
