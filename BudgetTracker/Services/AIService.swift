import Foundation
import Combine
import SwiftUI

struct OllamaChatMessage: Codable {
    let role: String
    let content: String
}

struct OllamaOptions: Codable {
    let num_predict: Int
}

struct OllamaChatRequest: Codable {
    let model: String
    let messages: [OllamaChatMessage]
    let stream: Bool
    let options: OllamaOptions?
    let think: Bool?
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
    @Published var prioritiesAssigned = false

    private let ollamaHost = "http://localhost:11434"
    private let model = "qwen3:8b"

    private init() {}

    func analyzeWishlist(
        items: [WishlistItem],
        totalSavings: Double,
        savingsGoal: Double,
        weeklyIncome: Double,
        weeklySavings: Double,
        weeks: [Week],
        expenses: [Expense]
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

        let savingsProgress = savingsGoal > 0 ? "\(totalSavings.formatted()) / \(savingsGoal.formatted()) PHP (\(Int(totalSavings / savingsGoal * 100))%)" : "\(totalSavings.formatted()) PHP"

        let recentWeeks = weeks.prefix(8).map { week in
            "- \(week.formattedDate): income \(week.income.formatted()), saved \(week.savings.formatted()), allowance \(week.allowance.formatted()), extra \(week.extraExpenses.formatted())\(week.extraExpensesNote.isEmpty ? "" : " (\(week.extraExpensesNote))")"
        }.joined(separator: "\n")

        let recentExpenses = expenses.prefix(20).map { expense in
            "- \(expense.formattedDate): \(expense.amount.formatted()) PHP — \(expense.categoryRaw)\(expense.note.isEmpty ? "" : " (\(expense.note))")"
        }.joined(separator: "\n")

        let totalSpent = expenses.reduce(0) { $0 + $1.amount }
        let topCategories = Dictionary(grouping: expenses, by: { $0.categoryRaw })
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { "- \($0.key): \($0.value.formatted()) PHP" }
            .joined(separator: "\n")

        let prompt = """
        I'm a Filipino worker tracking my budget. Analyze my finances and wishlist.

        SAVINGS STATUS:
        - Savings goal progress: \(savingsProgress)
        - Weekly income: \(weeklyIncome.formatted()) PHP
        - Weekly savings target: \(weeklySavings.formatted()) PHP
        - Savings goal reached: \(totalSavings >= savingsGoal ? "YES" : "NO, \((savingsGoal - totalSavings).formatted()) PHP remaining")

        SPENDING OVERVIEW:
        - Total spent on expenses: \(totalSpent.formatted()) PHP
        - Top spending categories:
        \(topCategories.isEmpty ? "No expenses yet" : topCategories)

        RECENT EXPENSES:
        \(recentExpenses.isEmpty ? "None yet" : recentExpenses)

        RECENT WEEKLY LOGS:
        \(recentWeeks.isEmpty ? "None yet" : recentWeeks)

        WISHLIST (total: \(totalWishlistCost.formatted()) PHP):
        \(itemsList)

        Give me:
        1. Savings check — Am I on track for my goal? Should I hold off buying anything until I hit it?
        2. Spending habits — Any patterns or categories where I'm overspending?
        3. Which wishlist items to prioritize and why (needs vs wants)
        4. Which items to skip or delay
        5. A suggested purchase order with timeline based on my savings rate
        6. Any red flags (items too expensive, impulse patterns, etc.)

        IMPORTANT: Savings goal comes first. If I haven't reached my savings goal yet, tell me to prioritize saving before buying wishlist items.

        Be direct and concise. Use PHP for currency. Do NOT use markdown formatting — no headers, no bold, no bullet symbols. Use plain text only with numbered lists and dashes.
        """

        do {
            let request = OllamaChatRequest(
                model: model,
                messages: [OllamaChatMessage(role: "user", content: prompt)],
                stream: false,
                options: OllamaOptions(num_predict: 1024),
                think: false
            )

            guard let url = URL(string: "\(ollamaHost)/api/chat") else {
                throw AIError.invalidURL
            }

            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = try JSONEncoder().encode(request)
            urlRequest.timeoutInterval = 300

            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIError.serverError
            }

            guard httpResponse.statusCode == 200 else {
                let body = String(data: data, encoding: .utf8) ?? ""
                throw AIError.httpError(statusCode: httpResponse.statusCode, body: body)
            }

            let chatResponse = try JSONDecoder().decode(OllamaChatResponse.self, from: data)
            lastAnalysis = stripMarkdown(chatResponse.message.content)

            await assignPriorities(items: items, analysis: chatResponse.message.content)

        } catch let urlError as URLError {
            error = "Can't reach Ollama (\(urlError.code.rawValue)): \(urlError.localizedDescription)"
        } catch {
            self.error = "Error: \(error.localizedDescription)"
        }

        isAnalyzing = false
    }

    private func assignPriorities(items: [WishlistItem], analysis: String) async {
        prioritiesAssigned = false

        let itemNames = items.filter { !$0.isPurchased }.map { $0.name }

        let prompt = """
        Based on this budget analysis, assign a priority to each wishlist item.

        Analysis:
        \(analysis)

        Items to prioritize:
        \(itemNames.joined(separator: ", "))

        Respond ONLY with a JSON object mapping each item name to its priority.
        Priorities: "high" (buy first/need), "medium" (can wait), "low" (low priority), "skip" (should not buy).
        Example: {"Item A": "high", "Item B": "skip"}
        Respond with ONLY the JSON, no other text.
        """

        do {
            let request = OllamaChatRequest(
                model: model,
                messages: [OllamaChatMessage(role: "user", content: prompt)],
                stream: false,
                options: OllamaOptions(num_predict: 256),
                think: false
            )

            guard let url = URL(string: "\(ollamaHost)/api/chat") else { return }

            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = try JSONEncoder().encode(request)
            urlRequest.timeoutInterval = 120

            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return }

            let chatResponse = try JSONDecoder().decode(OllamaChatResponse.self, from: data)
            let content = chatResponse.message.content.trimmingCharacters(in: .whitespacesAndNewlines)

            // Extract JSON from response (might have extra text)
            guard let jsonStart = content.firstIndex(of: "{"),
                  let jsonEnd = content.lastIndex(of: "}") else { return }

            let jsonString = String(content[jsonStart...jsonEnd])
            guard let jsonData = jsonString.data(using: .utf8),
                  let priorities = try? JSONDecoder().decode([String: String].self, from: jsonData) else { return }

            for item in items where !item.isPurchased {
                if let priorityStr = priorities[item.name]?.lowercased() {
                    switch priorityStr {
                    case "high": item.priority = .high
                    case "medium": item.priority = .medium
                    case "low": item.priority = .low
                    case "skip": item.priority = .skip
                    default: break
                    }
                }
            }

            prioritiesAssigned = true
        } catch {
            print("Priority assignment failed: \(error)")
        }
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
    case httpError(statusCode: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid Ollama URL"
        case .serverError: return "Ollama server error"
        case .httpError(let code, _): return "Ollama returned error \(code). The model may have timed out — try again."
        }
    }
}
