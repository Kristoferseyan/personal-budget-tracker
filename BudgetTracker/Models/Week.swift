import Foundation
import SwiftData

@Model
final class Week {
    var date: Date
    var income: Double
    var mom: Double
    var bills: Double
    var allowance: Double
    var extraExpenses: Double
    var extraExpensesNote: String
    var savings: Double

    init(
        date: Date = .now,
        income: Double = 8000,
        mom: Double = 1000,
        bills: Double = 275,
        allowance: Double = 1500,
        extraExpenses: Double = 0,
        extraExpensesNote: String = "",
        savings: Double = 5225
    ) {
        self.date = date
        self.income = income
        self.mom = mom
        self.bills = bills
        self.allowance = allowance
        self.extraExpenses = extraExpenses
        self.extraExpensesNote = extraExpensesNote
        self.savings = savings
    }

    var weekNumber: Int {
        Calendar.current.component(.weekOfYear, from: date)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Budget Configuration
enum BudgetConfig {
    static let goal: Double = 50_000
    static let defaultIncome: Double = 8_000
    static let defaultMom: Double = 1_000
    static let defaultBills: Double = 275
    static let defaultAllowance: Double = 1_500
    static let defaultSavings: Double = 5_225
}

// MARK: - Currency Formatter
extension Double {
    var asPHP: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₱"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: self)) ?? "₱0"
    }

    var asPHPDecimal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₱"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: self)) ?? "₱0.00"
    }
}
