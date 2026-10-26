import Foundation
import UIKit

// MARK: - Sharing

enum Sharing: String, Codable, CaseIterable {
    case justMe
    case everyone
    case selected

    var label: String {
        switch self {
        case .justMe: return "Just Me"
        case .everyone: return "Everyone"
        case .selected: return "Selected Roommates"
        }
    }
}

enum Freshness {
    case fresh, soon, urgent
}

// MARK: - Food

/// One item in the fridge. Stored at fridges/{fridgeId}/foods/{id}.
struct Food: Identifiable, Codable, Hashable {
    var id: String = ""
    var name: String
    /// Small JPEG sticker (background removed), base64. Kept in Firestore so no Storage plan is needed.
    var imageData: String?
    var expiry: Date
    var amount: Double
    var fullAmount: Double
    var unit: String
    var ownerId: String
    var ownerName: String
    var sharing: Sharing
    var sharedWith: [String]
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case name, imageData, expiry, amount, fullAmount, unit, ownerId, ownerName, sharing, sharedWith, createdAt
    }

    var isShared: Bool { sharing != .justMe }

    var daysLeft: Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.startOfDay(for: expiry)
        return cal.dateComponents([.day], from: start, to: end).day ?? 0
    }

    /// Same thresholds as the prototype: urgent = coral ring, soon = yellow ring.
    var freshness: Freshness {
        if daysLeft <= 1 { return .urgent }
        if daysLeft <= 3 { return .soon }
        return .fresh
    }

    var daysLabel: String {
        switch daysLeft {
        case ..<0: return "Expired"
        case 0: return "Expires today"
        case 1: return "1 day left"
        default: return "\(daysLeft) days left"
        }
    }

    var dateLabel: String { expiry.formatted(.dateTime.month(.abbreviated).day()) }

    var quantityLabel: String { "\(Food.format(amount)) \(unit)" }

    var image: UIImage? {
        guard let imageData, let data = Data(base64Encoded: imageData) else { return nil }
        return UIImage(data: data)
    }

    func isVisible(to uid: String) -> Bool {
        ownerId == uid || sharing == .everyone || sharedWith.contains(uid)
    }

    static func format(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

// MARK: - Fridge (household)

/// fridges/{id}. Roommates join with the invite code.
struct Fridge: Codable {
    var id: String = ""
    var inviteCode: String
    var memberIds: [String]
    var memberNames: [String: String]
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case inviteCode, memberIds, memberNames, createdAt
    }
}

struct Member: Identifiable, Hashable {
    let id: String
    let name: String
}

// MARK: - Offer ("Share it with..." for almost-expired food)

/// fridges/{fridgeId}/offers/{id}
struct Offer: Identifiable, Codable, Hashable {
    var id: String = ""
    var foodId: String
    var foodName: String
    var fromId: String
    var fromName: String
    var recipientIds: [String]
    var dismissedBy: [String]
    var claimedById: String?
    var claimedByName: String?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case foodId, foodName, fromId, fromName, recipientIds, dismissedBy, claimedById, claimedByName, createdAt
    }
}

// MARK: - Recipes (AI generated)

struct RecipeIngredient: Codable, Hashable {
    var name: String
    var amount: String
    var foodId: String?

    init(name: String, amount: String, foodId: String?) {
        self.name = name
        self.amount = amount
        self.foodId = foodId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? c.decode(String.self, forKey: .name)) ?? "Ingredient"
        amount = c.lenientString(.amount) ?? ""
        let id = try? c.decodeIfPresent(String.self, forKey: .foodId)
        foodId = (id == nil || id == "" || id == "null") ? nil : id
    }
}

extension KeyedDecodingContainer {
    /// Accepts "12", 12 or 12.0 for a string field.
    func lenientString(_ key: Key) -> String? {
        if let s = try? decode(String.self, forKey: key) { return s }
        if let i = try? decode(Int.self, forKey: key) { return String(i) }
        if let d = try? decode(Double.self, forKey: key) { return Food.format(d) }
        return nil
    }

    /// Accepts 12, 12.0 or "12 min" for a number field.
    func lenientDouble(_ key: Key) -> Double? {
        if let d = try? decode(Double.self, forKey: key) { return d }
        if let s = try? decode(String.self, forKey: key) {
            return Scanner(string: s).scanDouble()
        }
        return nil
    }
}

struct Recipe: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var emoji: String
    var minutes: Int
    var servings: Int
    var ingredients: [RecipeIngredient]
    var steps: [String]

    enum CodingKeys: String, CodingKey {
        case name, emoji, minutes, servings, ingredients, steps
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        emoji = (try? c.decode(String.self, forKey: .emoji)) ?? "🍳"
        minutes = Int(c.lenientDouble(.minutes) ?? 15)
        servings = Int(c.lenientDouble(.servings) ?? 2)
        ingredients = (try? c.decode([RecipeIngredient].self, forKey: .ingredients)) ?? []
        steps = (try? c.decode([String].self, forKey: .steps)) ?? []
    }
}

// MARK: - Scan result (before saving)

struct DetectedItem: Identifiable {
    let id = UUID()
    var name: String
    var expiry: Date
    var quantityText: String
    var sharing: Sharing = .justMe
    var sharedWith: [String] = []
    var sticker: UIImage?

    /// "2 pieces" -> (2, "pieces"); "Half" -> (1, "Half")
    var parsedQuantity: (amount: Double, unit: String) {
        let trimmed = quantityText.trimmingCharacters(in: .whitespaces)
        let scanner = Scanner(string: trimmed)
        if let number = scanner.scanDouble() {
            let rest = String(scanner.string[scanner.currentIndex...]).trimmingCharacters(in: .whitespaces)
            return (max(number, 0), rest.isEmpty ? "pcs" : rest)
        }
        return (1, trimmed.isEmpty ? "pcs" : trimmed)
    }
}
