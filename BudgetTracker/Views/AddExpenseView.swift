import SwiftUI
import SwiftData
import WidgetKit

// MARK: - Category Selection Type
enum CategorySelection: Equatable {
    case builtin(ExpenseCategory)
    case custom(CustomCategory)

    static func == (lhs: CategorySelection, rhs: CategorySelection) -> Bool {
        switch (lhs, rhs) {
        case (.builtin(let l), .builtin(let r)):
            return l == r
        case (.custom(let l), .custom(let r)):
            return l.id == r.id
        default:
            return false
        }
    }
}

struct AddExpenseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CustomCategory.createdAt) private var customCategories: [CustomCategory]

    @State private var amount: String = ""
    @State private var selectedCategory: CategorySelection = .builtin(.other)
    @State private var note: String = ""
    @State private var date: Date = .now
    @State private var showingAddCategory = false

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationStack {
            Form {
                // Amount Section
                Section {
                    HStack {
                        Text("₱")
                            .font(.title)
                            .foregroundColor(.secondary)
                        TextField("0", text: $amount)
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .keyboardType(.decimalPad)
                    }
                    .padding(.vertical, 8)
                }

                // Built-in Categories
                Section("Category") {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                            BuiltinCategoryButton(
                                category: cat,
                                isSelected: selectedCategory == .builtin(cat)
                            ) {
                                selectedCategory = .builtin(cat)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Custom Categories
                if !customCategories.isEmpty {
                    Section("Custom") {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(customCategories) { cat in
                                CustomCategoryButton(
                                    category: cat,
                                    isSelected: selectedCategory == .custom(cat)
                                ) {
                                    selectedCategory = .custom(cat)
                                }
                            }

                            // Add New Button
                            AddCategoryButton {
                                showingAddCategory = true
                            }
                        }
                        .padding(.vertical, 8)
                    }
                } else {
                    Section {
                        Button(action: { showingAddCategory = true }) {
                            Label("Create Custom Category", systemImage: "plus.circle.fill")
                        }
                    }
                }

                // Note Section
                Section("Note (optional)") {
                    TextField("e.g., cat food, gas", text: $note)
                }

                // Date Section
                Section {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
            }
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveExpense()
                    }
                    .disabled(amount.isEmpty || Double(amount) == nil)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingAddCategory) {
                AddCategoryView()
            }
        }
    }

    private func saveExpense() {
        guard let amountValue = Double(amount) else { return }

        let expense: Expense

        switch selectedCategory {
        case .builtin(let category):
            expense = Expense(
                date: date,
                amount: amountValue,
                category: category,
                note: note
            )
        case .custom(let customCategory):
            expense = Expense(
                date: date,
                amount: amountValue,
                customCategory: customCategory,
                note: note
            )
        }

        modelContext.insert(expense)
        WidgetCenter.shared.reloadAllTimelines()
        dismiss()
    }
}

// MARK: - Built-in Category Button
struct BuiltinCategoryButton: View {
    let category: ExpenseCategory
    let isSelected: Bool
    let action: () -> Void

    private var categoryColor: Color {
        colorFromName(category.color)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.title2)
                Text(category.rawValue)
                    .font(.caption)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? categoryColor.opacity(0.2) : Color(.systemGray6))
            .foregroundColor(isSelected ? categoryColor : .primary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? categoryColor : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Custom Category Button
struct CustomCategoryButton: View {
    let category: CustomCategory
    let isSelected: Bool
    let action: () -> Void

    private var categoryColor: Color {
        colorFromName(category.colorName)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.title2)
                Text(category.name)
                    .font(.caption)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? categoryColor.opacity(0.2) : Color(.systemGray6))
            .foregroundColor(isSelected ? categoryColor : .primary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? categoryColor : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Add Category Button
struct AddCategoryButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.title2)
                Text("New")
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .foregroundColor(.green)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.green.opacity(0.5), lineWidth: 1)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Color Helper
func colorFromName(_ name: String) -> Color {
    switch name {
    case "orange": return .orange
    case "blue": return .blue
    case "purple": return .purple
    case "pink": return .pink
    case "red": return .red
    case "green": return .green
    case "yellow": return .yellow
    case "teal": return .teal
    case "indigo": return .indigo
    case "brown": return .brown
    default: return .gray
    }
}

#Preview {
    AddExpenseView()
        .modelContainer(for: [Expense.self, CustomCategory.self], inMemory: true)
}
