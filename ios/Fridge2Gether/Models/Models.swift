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

    var quantityLabel: String { Food.quantityLabel(amount, unit) }

    /// "2 apples", "1 apple", "1 plate". The unit turns singular when there's exactly one.
    static func quantityLabel(_ amount: Double, _ unit: String) -> String {
        let trimmed = unit.trimmingCharacters(in: .whitespaces)
        let shown = amount == 1 ? singular(trimmed) : trimmed
        return shown.isEmpty ? format(amount) : "\(format(amount)) \(shown)"
    }

    /// apples → apple, berries → berry, boxes → box, glasses → glass. Leaves "g", "ml", "fish" alone.
    static func singular(_ word: String) -> String {
        let lower = word.lowercased()
        guard lower.count > 2, lower.hasSuffix("s"), !lower.hasSuffix("ss") else { return word }
        if lower.hasSuffix("ies") && lower.count > 4 { return String(word.dropLast(3)) + "y" }
        if ["oes", "xes", "ches", "shes", "sses"].contains(where: { lower.hasSuffix($0) }) { return String(word.dropLast(2)) }
        return String(word.dropLast())
    }

    /// Decoded once and cached. Decoding base64 on every render made the Recipes page lag.
    var image: UIImage? {
        guard let imageData else { return nil }
        let key = "\(id)#\(imageData.utf8.count)" as NSString
        if !id.isEmpty, let cached = FoodImageCache.shared.object(forKey: key) { return cached }
        guard let data = Data(base64Encoded: imageData), let decoded = UIImage(data: data) else { return nil }
        if !id.isEmpty { FoodImageCache.shared.setObject(decoded, forKey: key) }
        return decoded
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

/// Decoded food stickers, keyed by food id + data length.
enum FoodImageCache {
    static let shared: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 300
        return cache
    }()
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

extension Fridge {
    /// "My fridge" when it's just me, otherwise the roommates' names.
    func displayName(for uid: String) -> String {
        let others = memberIds.filter { $0 != uid }.map { memberNames[$0] ?? "Roommate" }
        guard !others.isEmpty else { return "My fridge" }
        let shown = others.prefix(3).joined(separator: ", ")
        return others.count > 3 ? "With \(shown) +\(others.count - 3)" : "With \(shown)"
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
        // The AI sometimes returns steps as objects or one long string. If steps came back empty,
        // "Start Cooking" was disabled and looked unclickable.
        if let list = try? c.decode([String].self, forKey: .steps) {
            steps = list
        } else if let objects = try? c.decode([RecipeStepObject].self, forKey: .steps) {
            steps = objects.compactMap(\.text)
        } else if let text = try? c.decode(String.self, forKey: .steps) {
            steps = text.split(separator: "\n").map { String($0) }
        } else {
            steps = []
        }
        steps = steps
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

/// One step written as {"text": "..."} / {"instruction": "..."} etc.
private struct RecipeStepObject: Decodable {
    let text: String?

    private struct AnyKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        for name in ["text", "instruction", "description", "content", "step"] {
            if let key = AnyKey(stringValue: name), let value = try? c.decode(String.self, forKey: key), !value.isEmpty {
                text = value
                return
            }
        }
        text = nil
    }
}

// MARK: - Scan result (before saving)

struct DetectedItem: Identifiable {
    let id = UUID()
    var name: String
    var expiry: Date
    /// How many, e.g. 2
    var amount: Double
    /// The counting word, e.g. "apples", "plates", "bottles", "g"
    var unit: String
    var sharing: Sharing = .justMe
    var sharedWith: [String] = []
    var sticker: UIImage?

    /// What gets saved. The unit is stored in its plural form ("apples"), so the label
    /// still reads right after some are used ("1 apple" → shown singular automatically).
    var parsedQuantity: (amount: Double, unit: String) {
        let trimmed = unit.trimmingCharacters(in: .whitespaces)
        return (amount > 0 ? amount : 1, trimmed.isEmpty ? "pieces" : trimmed)
    }

    /// Counting words offered in the Quantity menu. The AI's own word (e.g. "apples") is added on top.
    static let commonUnits = ["pieces", "plates", "bowls", "boxes", "bottles", "cans", "cartons",
                              "bags", "slices", "g", "kg", "ml", "L", "lb", "oz"]
}

// MARK: - Chat (one group per fridge)

/// fridges/{fridgeId}/messages/{id}
struct ChatMessage: Identifiable, Codable, Hashable {
    enum Kind: String, Codable {
        /// Something a roommate typed.
        case text
        /// Automatic note: food added, used up, claimed, someone joined.
        case event
        /// "Does anyone have eggs?" Roommates can answer with "I've got it".
        case request
        /// "Carrie is sharing milk": links to an Offer so it can be claimed from the chat.
        case offer

        init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = Kind(rawValue: raw) ?? .event
        }
    }

    var id: String = ""
    var kind: Kind
    var text: String
    var senderId: String
    var senderName: String
    var offerId: String?
    var fulfilledById: String?
    var fulfilledByName: String?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case kind, text, senderId, senderName, offerId, fulfilledById, fulfilledByName, createdAt
    }
}
