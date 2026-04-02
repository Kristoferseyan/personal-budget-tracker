import SwiftUI
import SwiftData

struct WishlistView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WishlistItem.dateAdded, order: .reverse) private var items: [WishlistItem]
    @Query(sort: \Week.date, order: .reverse) private var weeks: [Week]
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]

    @StateObject private var aiService = AIService.shared
    @AppStorage("savingsAdjustment") private var savingsAdjustment: Double = 0
    @AppStorage("savingsGoal") private var savingsGoal: Double = 50_000

    @State private var showAddItem = false
    @State private var showAIAnalysis = false
    @State private var filter: WishlistFilter = .pending

    enum WishlistFilter: String, CaseIterable {
        case pending = "To Buy"
        case purchased = "Bought"
        case all = "All"
    }

    private var filteredItems: [WishlistItem] {
        switch filter {
        case .pending: return items.filter { !$0.isPurchased }
        case .purchased: return items.filter { $0.isPurchased }
        case .all: return items
        }
    }

    private var totalPending: Double {
        items.filter { !$0.isPurchased }.reduce(0) { $0 + $1.estimatedPrice }
    }

    private var totalSavings: Double {
        let weekSavings = weeks.reduce(0) { $0 + $1.savings }
        let sortedWeeks = weeks.sorted { $0.date < $1.date }
        var totalOverage: Double = 0

        if !sortedWeeks.isEmpty {
            for (index, week) in sortedWeeks.enumerated() {
                let periodStart = week.date
                let periodEnd = index + 1 < sortedWeeks.count ? sortedWeeks[index + 1].date : Date.distantFuture
                let periodExpenses = expenses
                    .filter { $0.date >= periodStart && $0.date < periodEnd }
                    .reduce(0) { $0 + $1.amount }
                let weekBudget = week.allowance + week.extraExpenses
                let overage = periodExpenses - weekBudget
                if overage > 0 { totalOverage += overage }
            }
            let preWeekExpenses = expenses
                .filter { $0.date < sortedWeeks.first!.date }
                .reduce(0) { $0 + $1.amount }
            totalOverage += preWeekExpenses
        }

        return weekSavings - totalOverage + savingsAdjustment
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !items.filter({ !$0.isPurchased }).isEmpty {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Wishlist Total")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(totalPending.asPHP)
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Can Afford")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(totalSavings >= totalPending ? "Yes" : (totalSavings.asPHP + " short"))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(totalSavings >= totalPending ? .green : .orange)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                }

                Picker("Filter", selection: $filter) {
                    ForEach(WishlistFilter.allCases, id: \.self) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                if filteredItems.isEmpty {
                    ContentUnavailableView(
                        filter == .pending ? "No items yet" : "Nothing here",
                        systemImage: "gift",
                        description: Text(filter == .pending ? "Tap + to add something you want to buy" : "")
                    )
                } else {
                    List {
                        ForEach(filteredItems) { item in
                            WishlistRow(item: item) {
                                withAnimation { item.isPurchased.toggle() }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    modelContext.delete(item)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Wishlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showAIAnalysis = true
                        Task {
                            await aiService.analyzeWishlist(
                                items: items,
                                totalSavings: totalSavings,
                                savingsGoal: savingsGoal,
                                weeklyIncome: weeks.first?.income ?? BudgetConfig.defaultIncome,
                                weeklySavings: weeks.first?.savings ?? BudgetConfig.defaultSavings,
                                weeks: Array(weeks),
                                expenses: Array(expenses)
                            )
                        }
                    } label: {
                        Image(systemName: "sparkles")
                            .foregroundColor(.purple)
                    }
                    .disabled(aiService.isAnalyzing || items.filter({ !$0.isPurchased }).isEmpty)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddItem = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                    }
                }
            }
            .sheet(isPresented: $showAddItem) {
                AddWishlistItemView()
            }
            .sheet(isPresented: $showAIAnalysis) {
                AIAnalysisView(aiService: aiService)
            }
        }
    }
}

struct WishlistRow: View {
    let item: WishlistItem
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(item.isPurchased ? .green : .gray)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .fontWeight(.medium)
                    .strikethrough(item.isPurchased)
                    .foregroundColor(item.isPurchased ? .secondary : .primary)

                if !item.notes.isEmpty {
                    Text(item.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(item.estimatedPrice.asPHP)
                .fontWeight(.semibold)
                .foregroundColor(item.isPurchased ? .secondary : .primary)
        }
        .padding(.vertical, 4)
    }
}

struct AddWishlistItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var price: Double = 0
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Item name", text: $name)
                    HStack {
                        Text("₱")
                            .foregroundColor(.secondary)
                        TextField("Price", value: $price, format: .number)
                            .keyboardType(.numberPad)
                    }
                }

                Section("Notes (optional)") {
                    TextField("Why do you want this?", text: $notes, axis: .vertical)
                        .lineLimit(3)
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let item = WishlistItem(
                            name: name,
                            estimatedPrice: price,
                            notes: notes
                        )
                        modelContext.insert(item)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.isEmpty || price <= 0)
                }
            }
        }
    }
}

struct AIAnalysisView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var aiService: AIService
    @State private var elapsedSeconds = 0
    @State private var timer: Timer?

    private var sections: [AnalysisSection] {
        guard let text = aiService.lastAnalysis else { return [] }
        return parseAnalysis(text)
    }

    var body: some View {
        NavigationStack {
            Group {
                if aiService.isAnalyzing {
                    VStack(spacing: 24) {
                        Spacer()

                        ZStack {
                            Circle()
                                .stroke(Color.purple.opacity(0.2), lineWidth: 4)
                                .frame(width: 80, height: 80)
                            Circle()
                                .trim(from: 0, to: min(Double(elapsedSeconds) / 90.0, 0.95))
                                .stroke(Color.purple, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .frame(width: 80, height: 80)
                                .rotationEffect(.degrees(-90))
                                .animation(.linear(duration: 1), value: elapsedSeconds)
                            Image(systemName: "sparkles")
                                .font(.title)
                                .foregroundColor(.purple)
                        }

                        VStack(spacing: 8) {
                            Text("Analyzing your wishlist")
                                .font(.title3)
                                .fontWeight(.semibold)

                            Text("Qwen is evaluating your spending decisions")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        Text("\(elapsedSeconds)s")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)

                        Text("Usually takes 30-90 seconds")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()
                    }
                    .padding()
                } else if let error = aiService.error {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        Text("Couldn't reach AI")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Spacer()
                    }
                } else if !sections.isEmpty {
                    ScrollView {
                        VStack(spacing: 16) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.purple)
                                Text("AI Recommendation")
                                    .font(.headline)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)

                            ForEach(sections) { section in
                                AnalysisSectionCard(section: section)
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("AI Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .disabled(aiService.isAnalyzing)
                }
            }
            .interactiveDismissDisabled(aiService.isAnalyzing)
            .onAppear {
                elapsedSeconds = 0
                timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                    if aiService.isAnalyzing {
                        elapsedSeconds += 1
                    }
                }
            }
            .onDisappear {
                timer?.invalidate()
                timer = nil
            }
        }
    }

    private func parseAnalysis(_ text: String) -> [AnalysisSection] {
        let sectionPatterns: [(String, String, Color)] = [
            ("prioritize", "arrow.up.circle.fill", .green),
            ("skip", "hand.raised.fill", .red),
            ("delay", "clock.fill", .orange),
            ("purchase order", "list.number", .blue),
            ("timeline", "calendar", .blue),
            ("red flag", "flag.fill", .red),
            ("warning", "exclamationmark.triangle.fill", .orange),
        ]

        let lines = text.components(separatedBy: "\n")
        var sections: [AnalysisSection] = []
        var currentTitle = ""
        var currentLines: [String] = []
        var currentIcon = "lightbulb.fill"
        var currentColor: Color = .purple

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            let lower = trimmed.lowercased()
            var isHeader = false

            if let firstChar = trimmed.first, firstChar.isNumber && trimmed.contains(".") {
                let afterNumber = String(trimmed.drop(while: { $0.isNumber || $0 == "." || $0 == " " }))
                if !afterNumber.isEmpty {
                    let headerCheck = afterNumber.lowercased()
                    for (keyword, icon, color) in sectionPatterns {
                        if headerCheck.contains(keyword) {
                            if !currentTitle.isEmpty {
                                sections.append(AnalysisSection(
                                    title: currentTitle,
                                    content: currentLines.joined(separator: "\n"),
                                    icon: currentIcon,
                                    color: currentColor
                                ))
                            }
                            currentTitle = afterNumber
                            currentLines = []
                            currentIcon = icon
                            currentColor = color
                            isHeader = true
                            break
                        }
                    }

                    if !isHeader && currentTitle.isEmpty {
                        currentTitle = afterNumber
                        currentLines = []
                        currentIcon = "lightbulb.fill"
                        currentColor = .purple
                        isHeader = true
                    }
                }
            }

            if !isHeader {
                let cleaned = trimmed
                    .replacingOccurrences(of: "^[-*]\\s*", with: "", options: .regularExpression)
                currentLines.append(cleaned)
            }
        }

        if !currentTitle.isEmpty {
            sections.append(AnalysisSection(
                title: currentTitle,
                content: currentLines.joined(separator: "\n"),
                icon: currentIcon,
                color: currentColor
            ))
        }

        if sections.isEmpty && !text.isEmpty {
            sections.append(AnalysisSection(
                title: "Analysis",
                content: text,
                icon: "lightbulb.fill",
                color: .purple
            ))
        }

        return sections
    }
}

struct AnalysisSection: Identifiable {
    let id = UUID()
    let title: String
    let content: String
    let icon: String
    let color: Color
}

struct AnalysisSectionCard: View {
    let section: AnalysisSection

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: section.icon)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(section.color)
                    .cornerRadius(6)

                Text(section.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            Text(section.content)
                .font(.body)
                .foregroundColor(.primary.opacity(0.85))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

#Preview {
    WishlistView()
        .modelContainer(for: [WishlistItem.self, Week.self, Expense.self], inMemory: true)
}
