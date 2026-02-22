import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Week.date, order: .reverse) private var weeks: [Week]
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @AppStorage("savingsAdjustment") private var savingsAdjustment: Double = 0

    @State private var selectedWeek: Week?

    private var totalSavings: Double {
        let weekSavings = weeks.reduce(0) { $0 + $1.savings }
        let totalBudget = weeks.reduce(0) { $0 + $1.allowance + $1.extraExpenses }
        let totalExpenses = expenses.reduce(0) { $0 + $1.amount }
        let overage = max(0, totalExpenses - totalBudget)
        return weekSavings - overage + savingsAdjustment
    }

    var body: some View {
        NavigationStack {
            Group {
                if weeks.isEmpty {
                    EmptyHistoryView()
                } else {
                    List {
                        // Total Section
                        Section {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Total Saved")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text(totalSavings.asPHP)
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(totalSavings >= 0 ? .green : .red)
                                }

                                Spacer()

                                VStack(alignment: .trailing) {
                                    Text("Weeks Logged")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text("\(weeks.count)")
                                        .font(.title)
                                        .fontWeight(.bold)
                                }
                            }
                            .padding(.vertical, 8)
                        }

                        // History List
                        Section("History") {
                            ForEach(weeks) { week in
                                WeekRow(week: week)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedWeek = week
                                    }
                            }
                            .onDelete(perform: deleteWeeks)
                        }
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !weeks.isEmpty {
                    EditButton()
                }
            }
            .sheet(item: $selectedWeek) { week in
                EditWeekView(week: week)
            }
        }
    }

    private func deleteWeeks(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(weeks[index])
        }
    }
}

// MARK: - Week Row
struct WeekRow: View {
    let week: Week

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(week.formattedDate)
                    .font(.headline)

                Text("Week \(week.weekNumber)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if week.extraExpenses > 0 {
                    Text(week.extraExpensesNote.isEmpty ? "Extra: \(week.extraExpenses.asPHP)" : week.extraExpensesNote)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(week.savings.asPHP)
                    .font(.headline)
                    .foregroundColor(week.savings >= 0 ? .green : .red)

                HStack(spacing: 12) {
                    Label(week.mom.asPHP, systemImage: "heart.fill")
                        .font(.caption2)
                        .foregroundColor(.pink)

                    if week.extraExpenses > 0 {
                        Label(week.extraExpenses.asPHP, systemImage: "cart.fill")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Empty State
struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 64))
                .foregroundColor(.gray)

            Text("No Weeks Logged Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Start tracking your weekly savings\nby tapping + on the Dashboard")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: [Week.self, Expense.self], inMemory: true)
}
