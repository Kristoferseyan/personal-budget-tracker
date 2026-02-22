import Foundation
import SwiftData
import Combine

// MARK: - Sync Models
struct SyncWeekData: Codable {
    let id: String
    let date: String
    let income: Double
    let mom: Double
    let bills: Double
    let allowance: Double
    let extraExpenses: Double
    let extraExpensesNote: String
    let savings: Double
}

struct SyncExpenseData: Codable {
    let id: String
    let date: String
    let amount: Double
    let category: String
    let customCategoryId: String?
    let note: String
}

struct SyncCustomCategoryData: Codable {
    let id: String
    let name: String
    let icon: String
    let colorName: String
}

struct SyncBudgetData: Codable {
    let startingBalance: Double
    let weeks: [SyncWeekData]
    let expenses: [SyncExpenseData]?
    let customCategories: [SyncCustomCategoryData]?
    let lastModified: String
}

struct SyncResponse: Codable {
    let status: String
    let lastModified: String
    let message: String?
}

// MARK: - Sync Service
@MainActor
class SyncService: ObservableObject {
    static let shared = SyncService()

    private let baseURL = "https://your-server.example.com"
    private let apiKey = "your-api-key"

    @Published var isSyncing = false
    @Published var lastSyncTime: Date?
    @Published var syncError: String?

    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private init() {}

    // MARK: - Public Methods

    /// Sync data to server (push local data)
    func pushToServer(weeks: [Week], expenses: [Expense] = [], customCategories: [CustomCategory] = []) async {
        guard !isSyncing else { return }

        isSyncing = true
        syncError = nil

        do {
            let syncData = SyncBudgetData(
                startingBalance: 0,
                weeks: weeks.map { weekToSyncData($0) },
                expenses: expenses.map { expenseToSyncData($0) },
                customCategories: customCategories.map { customCategoryToSyncData($0) },
                lastModified: dateFormatter.string(from: Date())
            )

            guard let url = URL(string: "\(baseURL)/budget") else {
                throw SyncError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
            request.httpBody = try JSONEncoder().encode(syncData)
            request.timeoutInterval = 10

            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw SyncError.serverError
            }

            lastSyncTime = Date()
            UserDefaults.standard.set(Date(), forKey: "lastSyncTime")

        } catch {
            syncError = error.localizedDescription
            print("Sync push error: \(error)")
        }

        isSyncing = false
    }

    /// Fetch data from server
    func fetchFromServer() async -> SyncBudgetData? {
        guard !isSyncing else { return nil }

        isSyncing = true
        syncError = nil

        defer { isSyncing = false }

        do {
            guard let url = URL(string: "\(baseURL)/budget") else {
                throw SyncError.invalidURL
            }

            var request = URLRequest(url: url)
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
            request.timeoutInterval = 10

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw SyncError.serverError
            }

            let syncData = try JSONDecoder().decode(SyncBudgetData.self, from: data)
            lastSyncTime = Date()
            return syncData

        } catch {
            syncError = error.localizedDescription
            print("Sync fetch error: \(error)")
            return nil
        }
    }

    /// Check if server is reachable
    func checkConnection() async -> Bool {
        guard let url = URL(string: "\(baseURL)/") else { return false }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5

            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return httpResponse.statusCode == 200
        } catch {
            return false
        }
    }

    /// Check if server has data to restore
    func hasServerData() async -> Bool {
        if let data = await fetchFromServer() {
            return !data.weeks.isEmpty
        }
        return false
    }

    // MARK: - Helpers

    private func weekToSyncData(_ week: Week) -> SyncWeekData {
        SyncWeekData(
            id: week.persistentModelID.hashValue.description,
            date: displayDateFormatter.string(from: week.date),
            income: week.income,
            mom: week.mom,
            bills: week.bills,
            allowance: week.allowance,
            extraExpenses: week.extraExpenses,
            extraExpensesNote: week.extraExpensesNote,
            savings: week.savings
        )
    }

    private func expenseToSyncData(_ expense: Expense) -> SyncExpenseData {
        SyncExpenseData(
            id: expense.id.uuidString,
            date: displayDateFormatter.string(from: expense.date),
            amount: expense.amount,
            category: expense.categoryRaw,
            customCategoryId: expense.customCategoryId?.uuidString,
            note: expense.note
        )
    }

    private func customCategoryToSyncData(_ category: CustomCategory) -> SyncCustomCategoryData {
        SyncCustomCategoryData(
            id: category.id.uuidString,
            name: category.name,
            icon: category.icon,
            colorName: category.colorName
        )
    }
}

// MARK: - Errors
enum SyncError: LocalizedError {
    case invalidURL
    case serverError
    case networkError

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid server URL"
        case .serverError: return "Server error"
        case .networkError: return "Network unavailable"
        }
    }
}
