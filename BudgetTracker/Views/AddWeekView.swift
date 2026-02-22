import SwiftUI
import SwiftData

struct AddWeekView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var income: Double = BudgetConfig.defaultIncome
    @State private var mom: Double = BudgetConfig.defaultMom
    @State private var bills: Double = BudgetConfig.defaultBills
    @State private var allowance: Double = BudgetConfig.defaultAllowance
    @State private var extraExpenses: Double = 0
    @State private var extraExpensesNote: String = ""
    @State private var date: Date = .now

    private var savings: Double {
        income - mom - bills - allowance - extraExpenses
    }

    var body: some View {
        NavigationStack {
            Form {
                // Date Section
                Section {
                    DatePicker("Week of", selection: $date, displayedComponents: .date)
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

                // Savings Section (Calculated)
                Section("Savings") {
                    HStack {
                        Image(systemName: "banknote.fill")
                            .foregroundColor(.green)
                        Text("To Save")
                        Spacer()
                        Text(savings.asPHP)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(savings >= 0 ? .green : .red)
                    }
                    .padding(.vertical, 4)
                }

                // Summary
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Summary")
                            .font(.headline)

                        SummaryRow(label: "Income", amount: income)
                        SummaryRow(label: "Mom", amount: -mom)
                        SummaryRow(label: "Bills", amount: -bills)
                        SummaryRow(label: "Allowance", amount: -allowance)
                        if extraExpenses > 0 {
                            SummaryRow(label: "Extra Expenses", amount: -extraExpenses)
                        }

                        Divider()

                        HStack {
                            Text("Savings")
                                .fontWeight(.semibold)
                            Spacer()
                            Text(savings.asPHP)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Log Week")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveWeek()
                    }
                    .fontWeight(.semibold)
                    .disabled(false)
                }
            }
        }
    }

    private func saveWeek() {
        let week = Week(
            date: date,
            income: income,
            mom: mom,
            bills: bills,
            allowance: allowance,
            extraExpenses: extraExpenses,
            extraExpensesNote: extraExpensesNote,
            savings: savings
        )
        modelContext.insert(week)
        dismiss()
    }
}

// MARK: - Allocation Row
struct AllocationRow: View {
    let label: String
    @Binding var value: Double
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(label)
            Spacer()
            TextField(label, value: $value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
        }
    }
}

// MARK: - Summary Row
struct SummaryRow: View {
    let label: String
    let amount: Double

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(amount >= 0 ? "+\(amount.asPHP)" : amount.asPHP)
                .foregroundColor(amount >= 0 ? .primary : .red)
        }
        .font(.subheadline)
    }
}

#Preview {
    AddWeekView()
        .modelContainer(for: Week.self, inMemory: true)
}
