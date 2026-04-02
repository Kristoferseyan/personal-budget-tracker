import SwiftUI
import SwiftData

struct EditWeekView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var week: Week

    @State private var income: Double
    @State private var mom: Double
    @State private var bills: Double
    @State private var allowance: Double
    @State private var extraExpenses: Double
    @State private var extraExpensesNote: String
    @State private var savings: Double

    init(week: Week) {
        self.week = week
        _income = State(initialValue: week.income)
        _mom = State(initialValue: week.mom)
        _bills = State(initialValue: week.bills)
        _allowance = State(initialValue: week.allowance)
        _extraExpenses = State(initialValue: week.extraExpenses)
        _extraExpensesNote = State(initialValue: week.extraExpensesNote)
        _savings = State(initialValue: week.savings)
    }

    private var remainingAfterAllocations: Double {
        income - mom - bills - allowance - extraExpenses - savings
    }

    var body: some View {
        NavigationStack {
            Form {
                // Date (read-only)
                Section {
                    HStack {
                        Text("Week of")
                        Spacer()
                        Text(week.formattedDate)
                            .foregroundColor(.secondary)
                    }
                }

                // Income Section
                Section("Income") {
                    HStack {
                        Text("Weekly Salary")
                        Spacer()
                        TextField("Income", value: $income, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }

                // Allocations Section
                Section("Allocations") {
                    AllocationRow(label: "Mom", value: $mom, icon: "heart.fill", color: .pink)
                    AllocationRow(label: "Bills", value: $bills, icon: "bolt.fill", color: .yellow)
                    AllocationRow(label: "Allowance", value: $allowance, icon: "wallet.pass.fill", color: .blue)
                }

                // Extra Expenses Section
                Section("Extra Expenses") {
                    HStack {
                        Image(systemName: "cart.fill")
                            .foregroundColor(.red)
                        Text("Amount")
                        Spacer()
                        TextField("0", value: $extraExpenses, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }

                    HStack {
                        Image(systemName: "note.text")
                            .foregroundColor(.gray)
                        TextField("What was it for? (optional)", text: $extraExpensesNote)
                    }
                }

                Section("Savings") {
                    HStack {
                        Image(systemName: "banknote.fill")
                            .foregroundColor(.green)
                        Text("To Save")
                        Spacer()
                        TextField("0", value: $savings, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }

                    HStack {
                        Text("Goal: \(BudgetConfig.savingsGoal.asPHP)/week")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        if savings >= BudgetConfig.savingsGoal {
                            Label("On track", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else {
                            Label("\((BudgetConfig.savingsGoal - savings).asPHP) short", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }

                    if remainingAfterAllocations != 0 {
                        HStack {
                            Text("Unallocated")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(remainingAfterAllocations.asPHP)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(remainingAfterAllocations >= 0 ? .green : .red)
                        }
                    }
                }
            }
            .navigationTitle("Edit Week")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func saveChanges() {
        week.income = income
        week.mom = mom
        week.bills = bills
        week.allowance = allowance
        week.extraExpenses = extraExpenses
        week.extraExpensesNote = extraExpensesNote
        week.savings = savings
        dismiss()
    }
}

#Preview {
    EditWeekView(week: Week())
        .modelContainer(for: Week.self, inMemory: true)
}
