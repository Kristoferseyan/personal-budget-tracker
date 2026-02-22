import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Week.date, order: .reverse) private var weeks: [Week]
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @Query private var customCategories: [CustomCategory]

    @StateObject private var syncService = SyncService.shared
    @AppStorage("savingsAdjustment") private var savingsAdjustment: Double = 0
    @State private var showSyncSuccess = false
    @State private var showingAddWeek = false
    @State private var showRestoreAlert = false
    @State private var showAdjustBalance = false
    @State private var serverData: SyncBudgetData?

    private var totalWeekSavings: Double {
        weeks.reduce(0) { $0 + $1.savings }
    }

    private var totalExpenseOverage: Double {
        let sortedWeeks = weeks.sorted { $0.date < $1.date }
        guard !sortedWeeks.isEmpty else {
            return expenses.reduce(0) { $0 + $1.amount }
        }

        var totalOverage: Double = 0

        for (index, week) in sortedWeeks.enumerated() {
            let periodStart = week.date
            let periodEnd = index + 1 < sortedWeeks.count ? sortedWeeks[index + 1].date : Date.distantFuture

            let periodExpenses = expenses
                .filter { $0.date >= periodStart && $0.date < periodEnd }
                .reduce(0) { $0 + $1.amount }

            let weekBudget = week.allowance + week.extraExpenses
            let overage = periodExpenses - weekBudget
            if overage > 0 {
                totalOverage += overage
            }
        }

        let firstWeekDate = sortedWeeks.first!.date
        let preWeekExpenses = expenses
            .filter { $0.date < firstWeekDate }
            .reduce(0) { $0 + $1.amount }
        totalOverage += preWeekExpenses

        return totalOverage
    }

    private var totalSavings: Double {
        totalWeekSavings - totalExpenseOverage + savingsAdjustment
    }

    private var currentStreak: Int {
        guard !weeks.isEmpty else { return 0 }

        let sortedWeeks = weeks.sorted { $0.date > $1.date }
        let calendar = Calendar.current

        var streak = 0
        var expectedWeek = calendar.component(.weekOfYear, from: Date())
        var expectedYear = calendar.component(.year, from: Date())

        for week in sortedWeeks {
            let weekNum = calendar.component(.weekOfYear, from: week.date)
            let year = calendar.component(.year, from: week.date)

            if weekNum == expectedWeek && year == expectedYear {
                streak += 1
                expectedWeek -= 1
                if expectedWeek <= 0 {
                    expectedWeek = 52
                    expectedYear -= 1
                }
            } else if weekNum == expectedWeek - 1 || (expectedWeek == 1 && weekNum == 52) {
                streak += 1
                expectedWeek = weekNum - 1
                if expectedWeek <= 0 {
                    expectedWeek = 52
                    expectedYear -= 1
                }
            } else {
                break
            }
        }

        return streak
    }

    private var weeksToGo: Int {
        let remaining = BudgetConfig.goal - totalSavings
        guard remaining > 0 else { return 0 }
        return Int(ceil(remaining / BudgetConfig.defaultSavings))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    LargeProgressView(current: totalSavings, goal: BudgetConfig.goal)
                        .onTapGesture {
                            showAdjustBalance = true
                        }

                    HStack(spacing: 16) {
                        StatCard(
                            title: "Streak",
                            value: "\(currentStreak)",
                            subtitle: "weeks",
                            icon: "flame.fill",
                            color: .orange
                        )

                        StatCard(
                            title: "Weeks to Go",
                            value: "\(weeksToGo)",
                            subtitle: "remaining",
                            icon: "calendar",
                            color: .blue
                        )
                    }
                    .padding(.horizontal)

                    VStack(spacing: 12) {
                        InfoRow(label: "Weeks Logged", value: "\(weeks.count)")
                        InfoRow(label: "Weekly Target", value: BudgetConfig.defaultSavings.asPHP)
                        InfoRow(label: "Total Saved", value: totalSavings.asPHP)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Budget Tracker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        Task {
                            await syncService.pushToServer(weeks: weeks, expenses: expenses, customCategories: customCategories)
                            if syncService.syncError == nil {
                                withAnimation {
                                    showSyncSuccess = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation {
                                        showSyncSuccess = false
                                    }
                                }
                            }
                        }
                    }) {
                        if syncService.isSyncing {
                            ProgressView()
                                .scaleEffect(0.8)
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
                    Button(action: { showingAddWeek = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                    }
                }
            }
            .sheet(isPresented: $showingAddWeek) {
                AddWeekView()
            }
            .sheet(isPresented: $showAdjustBalance) {
                AdjustBalanceView(
                    calculatedSavings: totalWeekSavings - totalExpenseOverage,
                    savingsAdjustment: $savingsAdjustment
                )
            }
            .onAppear {
                Task {
                    guard await syncService.checkConnection() else { return }

                    if weeks.isEmpty && expenses.isEmpty && customCategories.isEmpty {
                        if let data = await syncService.fetchFromServer(), !data.weeks.isEmpty {
                            serverData = data
                            showRestoreAlert = true
                        }
                    } else {
                        await syncService.pushToServer(weeks: weeks, expenses: expenses, customCategories: customCategories)
                        if syncService.syncError == nil {
                            withAnimation { showSyncSuccess = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation { showSyncSuccess = false }
                            }
                        }
                    }
                }
            }
            .alert("Restore Data?", isPresented: $showRestoreAlert) {
                Button("Restore") {
                    restoreFromServer()
                }
                Button("Start Fresh", role: .cancel) {}
            } message: {
                Text("Found \(serverData?.weeks.count ?? 0) weeks on your server. Restore this data?")
            }
        }
    }

    private func restoreFromServer() {
        guard let data = serverData else { return }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for weekData in data.weeks {
            let week = Week(
                date: dateFormatter.date(from: weekData.date) ?? Date(),
                income: weekData.income,
                mom: weekData.mom,
                bills: weekData.bills,
                allowance: weekData.allowance,
                extraExpenses: weekData.extraExpenses,
                extraExpensesNote: weekData.extraExpensesNote,
                savings: weekData.savings
            )
            modelContext.insert(week)
        }

        withAnimation { showSyncSuccess = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showSyncSuccess = false }
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

// MARK: - Info Row
struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - Adjust Balance View
struct AdjustBalanceView: View {
    @Environment(\.dismiss) private var dismiss

    let calculatedSavings: Double
    @Binding var savingsAdjustment: Double

    @State private var actualBalance: Double = 0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tracked Savings")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text((calculatedSavings + savingsAdjustment).asPHP)
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    .padding(.vertical, 4)
                }

                Section("Actual Bank Balance") {
                    HStack {
                        Text("₱")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        TextField("0", value: $actualBalance, format: .number)
                            .keyboardType(.numberPad)
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                }

                if actualBalance != 0 {
                    Section {
                        let diff = actualBalance - (calculatedSavings + savingsAdjustment)
                        HStack {
                            Text("Difference")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text((diff >= 0 ? "+" : "") + diff.asPHP)
                                .fontWeight(.semibold)
                                .foregroundColor(diff >= 0 ? .green : .red)
                        }
                    }
                }
            }
            .navigationTitle("Adjust Balance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savingsAdjustment = actualBalance - calculatedSavings
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(actualBalance == 0)
                }
            }
            .onAppear {
                actualBalance = calculatedSavings + savingsAdjustment
            }
        }
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [Week.self, Expense.self, CustomCategory.self], inMemory: true)
}
