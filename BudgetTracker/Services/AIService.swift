import Foundation
import Combine

struct OllamaChatMessage: Codable {
    let role: String
    let content: String
}

struct OllamaChatRequest: Codable {
    let model: String
    let messages: [OllamaChatMessage]
    let stream: Bool
}

struct OllamaChatResponse: Codable {
    let message: OllamaChatMessage
}

@MainActor
class AIService: ObservableObject {
    static let shared = AIService()

    @Published var isAnalyzing = false
    @Published var lastAnalysis: String?
    @Published var error: String?

    private let ollamaHost = "http://localhost:11434"
    private let model = "qwen3:8b"

    private init() {}

    func analyzeWishlist(
        items: [WishlistItem],
        totalSavings: Double,
        weeklyIncome: Double,
        weeklySavings: Double
    ) async {
        guard !items.isEmpty else {
            lastAnalysis = "Add some items to your wishlist first."
            return
        }

        isAnalyzing = true
        error = nil
        lastAnalysis = nil

        let itemsList = items.filter { !$0.isPurchased }.map { item in
            "- \(item.name): \(item.estimatedPrice.formatted()) PHP\(item.notes.isEmpty ? "" : " — \(item.notes)")"
        }.joined(separator: "\n")

        let totalWishlistCost = items.filter { !$0.isPurchased }.reduce(0) { $0 + $1.estimatedPrice }

        let prompt = """
        I'm a Filipino worker tracking my budget. Analyze my wishlist and help me prioritize.

        My finances:
        - Weekly income: \(weeklyIncome.formatted()) PHP
        - Weekly savings target: \(weeklySavings.formatted()) PHP
        - Current total savings: \(totalSavings.formatted()) PHP

        My wishlist (total: \(totalWishlistCost.formatted()) PHP):
        \(itemsList)

        Give me:
        1. Which items to prioritize and why (needs vs wants)
        2. Which items to skip or delay
        3. A suggested purchase order with timeline based on my savings rate
        4. Any red flags (items too expensive for my income, impulse buys, etc.)

        Be direct and concise. Use PHP for currency. Do NOT use markdown formatting — no headers, no bold, no bullet symbols. Use plain text only with numbered lists and dashes.
        /no_think
        """

        do {
            let request = OllamaChatRequest(
                model: model,
                messages: [OllamaChatMessage(role: "user", content: prompt)],
                stream: false
            )

            guard let url = URL(string: "\(ollamaHost)/api/chat") else {
                throw AIError.invalidURL
            }

            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = try JSONEncoder().encode(request)
            urlRequest.timeoutInterval = 120

            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw AIError.serverError
            }

            let chatResponse = try JSONDecoder().decode(OllamaChatResponse.self, from: data)
            lastAnalysis = stripMarkdown(chatResponse.message.content)

        } catch is URLError {
            error = "Can't reach Ollama. Make sure it's running on your Mac with OLLAMA_HOST=0.0.0.0"
        } catch {
            self.error = error.localizedDescription
        }

        isAnalyzing = false
    }

    private func stripMarkdown(_ text: String) -> String {
        var result = text
        // Remove think tags and content
        if let thinkRange = result.range(of: "<think>[\\s\\S]*?</think>", options: .regularExpression) {
            result.removeSubrange(thinkRange)
        }
        // Remove headers (### Header)
        result = result.replacingOccurrences(of: "#{1,6}\\s*", with: "", options: .regularExpression)
        // Remove bold/italic (**text** or *text*)
        result = result.replacingOccurrences(of: "\\*{1,3}([^*]+)\\*{1,3}", with: "$1", options: .regularExpression)
        // Remove horizontal rules
        result = result.replacingOccurrences(of: "^---+$", with: "", options: [.regularExpression, .anchored])
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum AIError: LocalizedError {
    case invalidURL
    case serverError

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid Ollama URL"
        case .serverError: return "Ollama server error"
        }
    }
}
