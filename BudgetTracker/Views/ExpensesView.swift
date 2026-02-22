import SwiftUI
import SwiftData

// MARK: - Category Summary Item
struct CategorySummaryItem: Identifiable {
    let id: String
    let name: String
    let icon: String
    let colorName: String
    let total: Double

    var color: Color {
        colorFromName(colorName)
    }
}

struct ExpensesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Expense.date, order: .reverse) private var allExpenses: [Expense]
    @Query(sort: \Week.date, order: .reverse) private var weeks: [Week]
    @Query private var customCategories: [CustomCategory]

    @StateObject private var syncService = SyncService.shared
    @Binding var showAddExpense: Bool
    @State private var selectedMonth: Date = .now
    @State private var showSyncSuccess = false

    private var currentMonthExpenses: [Expense] {
        let calendar = Calendar.current
        return allExpenses.filter { expense in
            calendar.isDate(expense.date, equalTo: selectedMonth, toGranularity: .month)
        }
    }

    private var totalThisMonth: Double {
        currentMonthExpenses.reduce(0) { $0 + $1.amount }
    }

    private var latestWeekInMonth: Week? {
        let calendar = Calendar.current
        return weeks
            .filter { calendar.isDate($0.date, equalTo: selectedMonth, toGranularity: .month) }
            .sorted { $0.date > $1.date }
            .first
    }

    private var weeklyBudget: Double {
        guard let latest = latestWeekInMonth else { return 0 }
        return latest.allowance + latest.extraExpenses
    }

    private var expensesSinceLatestWeek: Double {
        guard let latest = latestWeekInMonth else { return totalThisMonth }
        return currentMonthExpenses
            .filter { $0.date >= latest.date }
            .reduce(0) { $0 + $1.amount }
    }

    private var remainingBudget: Double {
        weeklyBudget - expensesSinceLatestWeek
    }

    private var expensesByCategory: [CategorySummaryItem] {
        var totals: [String: (name: String, icon: String, color: String, total: Double)] = [:]

        for expense in currentMonthExpenses {
            let key: String
            let name: String
            let icon: String
            let color: String

            if let customId = expense.customCategoryId,
               let custom = customCategories.first(where: { $0.id == customId }) {
                key = "custom_\(customId.uuidString)"
                name = custom.name
                icon = custom.icon
                color = custom.colorName
            } else {
                key = "builtin_\(expense.category.rawValue)"
                name = expense.category.rawValue
                icon = expense.category.icon
                color = expense.category.color
            }

            if var existing = totals[key] {
                existing.total += expense.amount
                totals[key] = existing
            } else {
                totals[key] = (name, icon, color, expense.amount)
            }
        }

        return totals.map { CategorySummaryItem(id: $0.key, name: $0.value.name, icon: $0.value.icon, colorName: $0.value.color, total: $0.value.total) }
            .sorted { $0.total > $1.total }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    MonthSelector(selectedMonth: $selectedMonth)

                    VStack(spacing: 4) {
                        Text("Total Spent")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(totalThisMonth.asPHP)
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 8)

                    if weeklyBudget > 0 {
                        VStack(spacing: 4) {
                            Text("Remaining Budget")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(remainingBudget.asPHP)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(remainingBudget >= 0 ? .green : .red)
                            Text("of \(weeklyBudget.asPHP) weekly allowance")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if !expensesByCategory.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("By Category")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(expensesByCategory) { item in
                                CategorySummaryRow(
                                    item: item,
                                    percentage: totalThisMonth > 0 ? item.total / totalThisMonth : 0
                                )
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Expenses")
                            .font(.headline)
                            .padding(.horizontal)

                        if currentMonthExpenses.isEmpty {
                            Text("No expenses this month")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                        } else {
                            ForEach(currentMonthExpenses) { expense in
                                ExpenseRow(expense: expense, customCategories: customCategories)
                            }
                            .onDelete(perform: deleteExpenses)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    .padding(.horizontal)
                }
                .padding(.bottom, 80)
            }
            .navigationTitle("Expenses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        Task {
                            await syncService.pushToServer(weeks: weeks, expenses: allExpenses, customCategories: customCategories)
                            if syncService.syncError == nil {
                                withAnimation { showSyncSuccess = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation { showSyncSuccess = false }
                                }
                            }
                        }
                    }) {
                        if syncService.isSyncing {
                            ProgressView().scaleEffect(0.8)
                        } else if showSyncSuccess {
                            Image(systemName: "checkmark.icloud.fill")
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: syncService.syncError != nil ? "exclamationmark.icloud" : "icloud")
                                .foregroundColor(syncService.syncError != nil ? .red : .green)
                        }
                    }
                    .disabled(syncService.isSyncing)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showAddExpense = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                    }
                }
            }
            .sheet(isPresented: $showAddExpense) {
                AddExpenseView()
            }
        }
    }

    private func deleteExpenses(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(currentMonthExpenses[index])
        }
    }
}

// MARK: - Month Selector
struct MonthSelector: View {
    @Binding var selectedMonth: Date

    var body: some View {
        HStack {
            Button(action: previousMonth) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.green)
            }

            Spacer()

            Text(monthYearString)
                .font(.title3)
                .fontWeight(.semibold)

            Spacer()

            Button(action: nextMonth) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(.green)
            }
            .disabled(isCurrentMonth)
            .opacity(isCurrentMonth ? 0.3 : 1)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedMonth)
    }

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(selectedMonth, equalTo: .now, toGranularity: .month)
    }

    private func previousMonth() {
        if let newDate = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) {
            selectedMonth = newDate
        }
    }

    private func nextMonth() {
        if let newDate = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) {
            selectedMonth = newDate
        }
    }
}

// MARK: - Category Summary Row
struct CategorySummaryRow: View {
    let item: CategorySummaryItem
    let percentage: Double

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.title3)
                .foregroundColor(item.color)
                .frame(width: 32)

            Text(item.name)
                .foregroundColor(.primary)

            Spacer()

            Text(item.total.asPHP)
                .fontWeight(.semibold)

            Text("\(Int(percentage * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
        .padding(.horizontal)
    }
}

// MARK: - Expense Row
struct ExpenseRow: View {
    let expense: Expense
    let customCategories: [CustomCategory]

    private var displayInfo: (icon: String, color: Color, name: String) {
        if let customId = expense.customCategoryId,
           let custom = customCategories.first(where: { $0.id == customId }) {
            return (custom.icon, colorFromName(custom.colorName), custom.name)
        } else {
            return (expense.category.icon, colorFromName(expense.category.color), expense.category.rawValue)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: displayInfo.icon)
                .font(.title3)
                .foregroundColor(displayInfo.color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(expense.note.isEmpty ? displayInfo.name : expense.note)
                    .foregroundColor(.primary)
                Text(expense.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(expense.amount.asPHP)
                .fontWeight(.semibold)
        }
        .padding(.horizontal)
    }
}

#Preview {
    ExpensesView(showAddExpense: .constant(false))
        .modelContainer(for: [Week.self, Expense.self, CustomCategory.self], inMemory: true)
}
