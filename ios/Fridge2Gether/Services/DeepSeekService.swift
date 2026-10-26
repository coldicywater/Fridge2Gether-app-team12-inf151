import Foundation
import UIKit

/// Talks to DeepSeek's OpenAI-compatible chat API.
/// `deepseek-flash` (V4.1 Flash) accepts images, so one model handles both scanning and recipes.
enum DeepSeekService {
    private static let endpoint = URL(string: "https://api.deepseek.com/chat/completions")!
    private static let model = "deepseek-flash"

    private static var apiKey: String {
        (Bundle.main.object(forInfoDictionaryKey: "DEEPSEEK_API_KEY") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Scan groceries

    struct ScannedItem: Decodable {
        var name: String
        var quantity: Double?
        var unit: String?
        var shelfLifeDays: Int?
        /// [x, y, width, height], normalized 0...1 from the top-left corner.
        var box: [Double]?

        enum CodingKeys: String, CodingKey { case name, quantity, unit, shelfLifeDays, box }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name = (try? c.decode(String.self, forKey: .name)) ?? ""
            quantity = c.lenientDouble(.quantity)
            unit = c.lenientString(.unit)
            shelfLifeDays = c.lenientDouble(.shelfLifeDays).map { Int($0) }
            box = try? c.decode([Double].self, forKey: .box)
        }
    }

    private struct ScanResponse: Decodable {
        var items: [ScannedItem]
    }

    static func scanGroceries(_ image: UIImage) async throws -> [ScannedItem] {
        let small = ImageProcessor.resized(image, maxSide: 1024)
        guard let jpeg = small.jpegData(compressionQuality: 0.8) else {
            throw AppError.message("Could not read the photo.")
        }
        let prompt = """
        You are the grocery scanner inside a fridge app. Look at the photo and list each distinct food item \
        (at most 8). Group identical items into one entry with a count.
        Reply with JSON only, in this shape:
        {"items":[{"name":"Avocado","quantity":2,"unit":"pieces","shelfLifeDays":4,"box":[0.1,0.2,0.3,0.25]}]}
        Rules:
        - name: short English name a person would write on a label, Title case.
        - quantity + unit: your best guess, e.g. 2 pieces, 500 ml, 1 bag, 1 carton.
        - shelfLifeDays: how many days from today it stays good in a home fridge.
        - box: bounding box of the item as [x, y, width, height], each between 0 and 1, origin top-left.
        - If you see no food, return {"items":[]}.
        """
        let content: [[String: Any]] = [
            ["type": "text", "text": prompt],
            ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(jpeg.base64EncodedString())"]],
        ]
        let text = try await chat(messages: [["role": "user", "content": content]])
        let response = try decodeJSON(ScanResponse.self, from: text)
        return response.items.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    // MARK: - Recipes

    private struct RecipeResponse: Decodable {
        var recipes: [Recipe]
    }

    static func recipes(for foods: [Food]) async throws -> [Recipe] {
        let inventory: [[String: Any]] = foods.map { food in
            [
                "foodId": food.id,
                "name": food.name,
                "quantity": food.quantityLabel,
                "daysLeft": food.daysLeft,
            ]
        }
        let inventoryJSON = String(
            data: try JSONSerialization.data(withJSONObject: inventory, options: [.sortedKeys]),
            encoding: .utf8
        ) ?? "[]"

        let prompt = """
        You suggest home recipes for roommates who share a fridge and want to waste less food.
        Fridge inventory (daysLeft = days until it expires):
        \(inventoryJSON)

        Suggest 3 simple recipes. Put recipes that use items with the smallest daysLeft first.
        Each recipe may add 1 or 2 common pantry items that are not in the fridge.
        Reply with JSON only, in this shape:
        {"recipes":[{"name":"Creamy avocado toast","emoji":"🥑","minutes":12,"servings":2,
          "ingredients":[{"name":"Avocado","amount":"1 ripe","foodId":"<id from inventory or null>"}],
          "steps":["Toast the sourdough until the edges are golden."]}]}
        Rules:
        - foodId must be copied exactly from the inventory when the ingredient is in the fridge, otherwise null.
        - 3 or 4 short steps per recipe, each one sentence.
        - emoji: one food emoji that fits the dish.
        - If the fridge is empty, suggest 3 easy pantry recipes with every foodId null.
        """
        let text = try await chat(messages: [["role": "user", "content": prompt]])
        return try decodeJSON(RecipeResponse.self, from: text).recipes
    }

    // MARK: - Networking

    private static func chat(messages: [[String: Any]]) async throws -> String {
        guard !apiKey.isEmpty, !apiKey.hasPrefix("$(") else {
            throw AppError.message("DeepSeek API key is missing. Add it to Secrets.xcconfig.")
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "response_format": ["type": "json_object"],
            "temperature": 0.4,
            "stream": false,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let detail = String(data: data, encoding: .utf8) ?? ""
            throw AppError.message("AI request failed (\(status)). \(detail.prefix(160))")
        }
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            throw AppError.message("AI returned an unexpected response.")
        }
        return content
    }

    /// Models sometimes wrap JSON in ```json fences; strip them before decoding.
    private static func decodeJSON<T: Decodable>(_ type: T.Type, from text: String) throws -> T {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = cleaned.firstIndex(of: "{"), let end = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[start...end])
        }
        guard let data = cleaned.data(using: .utf8) else {
            throw AppError.message("AI returned unreadable text.")
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw AppError.message("AI returned JSON in an unexpected shape.")
        }
    }
}
