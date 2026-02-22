import WidgetKit
import SwiftUI

// MARK: - API Response Models
struct WidgetBudgetResponse: Codable {
    let startingBalance: Double
    let weeks: [WidgetWeekData]
    let expenses: [WidgetExpenseData]?
    let lastModified: String
}

struct WidgetWeekData: Codable {
    let date: String
    let allowance: Double
    let savings: Double
}

struct WidgetExpenseData: Codable {
    let date: String
    let amount: Double
}

let savingsGoal: Double = 50_000
let weeklySavingsTarget: Double = 5_225

// MARK: - Currency Formatter
extension Double {
    var asPHP: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₱"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: self)) ?? "₱0"
    }
}

// MARK: - Budget Summary Result
struct BudgetSummary {
    let allowance: Double
    let spent: Double
    let remaining: Double
    let totalSaved: Double
    let weeksToGo: Int
}

// MARK: - Data Fetching
func fetchBudgetSummary() async -> BudgetSummary {
    let defaultAllowance = 1500.0
    let fallback = BudgetSummary(allowance: defaultAllowance, spent: 0, remaining: defaultAllowance, totalSaved: 0, weeksToGo: 10)

    guard let url = URL(string: "https://your-server.example.com/budget") else {
        return fallback
    }

    var request = URLRequest(url: url)
    request.setValue("your-api-key", forHTTPHeaderField: "X-API-Key")
    request.timeoutInterval = 10

    do {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return fallback
        }

        let budget = try JSONDecoder().decode(WidgetBudgetResponse.self, from: data)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let sortedWeeks = budget.weeks
            .compactMap { week -> (date: Date, allowance: Double, savings: Double)? in
                guard let date = dateFormatter.date(from: week.date) else { return nil }
                return (date, week.allowance, week.savings)
            }
            .sorted { $0.date > $1.date }

        guard let mostRecent = sortedWeeks.first else {
            return fallback
        }

        let allowance = mostRecent.allowance

        let expenses = budget.expenses ?? []
        let spent = expenses
            .compactMap { expense -> Double? in
                guard let date = dateFormatter.date(from: expense.date) else { return nil }
                return date >= mostRecent.date ? expense.amount : nil
            }
            .reduce(0, +)

        let remaining = allowance - spent

        let totalSaved = budget.startingBalance + budget.weeks.reduce(0) { $0 + $1.savings }

        let leftToSave = max(savingsGoal - totalSaved, 0)
        let weeksToGo = weeklySavingsTarget > 0 ? Int(ceil(leftToSave / weeklySavingsTarget)) : 0

        return BudgetSummary(allowance: allowance, spent: spent, remaining: remaining, totalSaved: totalSaved, weeksToGo: weeksToGo)

    } catch {
        return fallback
    }
}

// MARK: - Timeline Entry
struct BudgetEntry: TimelineEntry {
    let date: Date
    let allowance: Double
    let spent: Double
    let remaining: Double
    let totalSaved: Double
    let weeksToGo: Int
}

// MARK: - Timeline Provider
struct BudgetTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> BudgetEntry {
        BudgetEntry(date: .now, allowance: 1500, spent: 0, remaining: 1500, totalSaved: 26125, weeksToGo: 5)
    }

    func getSnapshot(in context: Context, completion: @escaping (BudgetEntry) -> Void) {
        if context.isPreview {
            completion(BudgetEntry(date: .now, allowance: 1500, spent: 350, remaining: 1150, totalSaved: 26125, weeksToGo: 5))
            return
        }
        Task {
            let s = await fetchBudgetSummary()
            completion(BudgetEntry(date: .now, allowance: s.allowance, spent: s.spent, remaining: s.remaining, totalSaved: s.totalSaved, weeksToGo: s.weeksToGo))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BudgetEntry>) -> Void) {
        Task {
            let s = await fetchBudgetSummary()
            let entry = BudgetEntry(date: .now, allowance: s.allowance, spent: s.spent, remaining: s.remaining, totalSaved: s.totalSaved, weeksToGo: s.weeksToGo)
            let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
            let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
            completion(timeline)
        }
    }
}

// MARK: - Small Widget View
struct SmallBudgetView: View {
    let entry: BudgetEntry

    var body: some View {
        VStack(spacing: 4) {
            Text("Remaining")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(entry.remaining.asPHP)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(entry.remaining >= 0 ? .green : .red)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text("of \(entry.allowance.asPHP)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(URL(string: "budgettracker://add-expense"))
    }
}

// MARK: - Medium Widget View
struct MediumBudgetView: View {
    let entry: BudgetEntry

    private var progress: Double {
        guard entry.allowance > 0 else { return 0 }
        return min(entry.spent / entry.allowance, 1.0)
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Weekly Budget")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(entry.remaining.asPHP)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(entry.remaining >= 0 ? .green : .red)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                Text("\(entry.spent.asPHP) of \(entry.allowance.asPHP) spent")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.quaternary)
                            .frame(height: 6)

                        Capsule()
                            .fill(progress > 0.8 ? .red : .green)
                            .frame(width: geo.size.width * progress, height: 6)
                    }
                }
                .frame(height: 6)
            }

            Link(destination: URL(string: "budgettracker://add-expense")!) {
                VStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                        .foregroundStyle(.green)
                    Text("Add")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
                .frame(width: 50)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Lock Screen: Inline
struct InlineBudgetView: View {
    let entry: BudgetEntry

    var body: some View {
        Text("\(entry.weeksToGo)w to ₱50k — \(entry.remaining.asPHP) left")
            .containerBackground(.clear, for: .widget)
    }
}

// MARK: - Lock Screen: Circular
struct CircularBudgetView: View {
    let entry: BudgetEntry

    private var progress: Double {
        guard savingsGoal > 0 else { return 0 }
        return min(entry.totalSaved / savingsGoal, 1.0)
    }

    var body: some View {
        Gauge(value: progress) {
            Text("wk")
                .font(.caption2)
        } currentValueLabel: {
            Text("\(entry.weeksToGo)")
                .font(.system(.title3, design: .rounded, weight: .bold))
        }
        .gaugeStyle(.accessoryCircular)
        .containerBackground(.clear, for: .widget)
    }
}

// MARK: - Lock Screen: Rectangular
struct RectangularBudgetView: View {
    let entry: BudgetEntry

    private var progress: Double {
        guard savingsGoal > 0 else { return 0 }
        return min(entry.totalSaved / savingsGoal, 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(entry.weeksToGo) weeks to ₱50k")
                .font(.system(.headline, design: .rounded, weight: .bold))

            Text("\(entry.totalSaved.asPHP) saved")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Gauge(value: progress) {
                EmptyView()
            }
            .gaugeStyle(.accessoryLinear)
        }
        .containerBackground(.clear, for: .widget)
    }
}

// MARK: - Widget Configuration
struct BudgetWidget: Widget {
    let kind: String = "BudgetWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BudgetTimelineProvider()) { entry in
            BudgetWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Weekly Budget")
        .description("Track your remaining weekly allowance.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular,
        ])
    }
}

struct BudgetWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: BudgetEntry

    var body: some View {
        switch family {
        case .systemMedium:
            MediumBudgetView(entry: entry)
        case .accessoryInline:
            InlineBudgetView(entry: entry)
        case .accessoryCircular:
            CircularBudgetView(entry: entry)
        case .accessoryRectangular:
            RectangularBudgetView(entry: entry)
        default:
            SmallBudgetView(entry: entry)
        }
    }
}

#Preview(as: .systemSmall) {
    BudgetWidget()
} timeline: {
    BudgetEntry(date: .now, allowance: 1500, spent: 350, remaining: 1150, totalSaved: 26125, weeksToGo: 5)
}

#Preview(as: .systemMedium) {
    BudgetWidget()
} timeline: {
    BudgetEntry(date: .now, allowance: 1500, spent: 350, remaining: 1150, totalSaved: 26125, weeksToGo: 5)
}

#Preview(as: .accessoryCircular) {
    BudgetWidget()
} timeline: {
    BudgetEntry(date: .now, allowance: 1500, spent: 1000, remaining: 500, totalSaved: 26125, weeksToGo: 5)
}

#Preview(as: .accessoryRectangular) {
    BudgetWidget()
} timeline: {
    BudgetEntry(date: .now, allowance: 1500, spent: 1000, remaining: 500, totalSaved: 26125, weeksToGo: 5)
}
