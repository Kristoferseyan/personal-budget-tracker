import SwiftUI
import SwiftData

@main
struct BudgetTrackerApp: App {
    @State private var selectedTab = 0
    @State private var showAddExpense = false

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Week.self,
            Expense.self,
            CustomCategory.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView(selectedTab: $selectedTab, showAddExpense: $showAddExpense)
                .onOpenURL { url in
                    if url.scheme == "budgettracker" && url.host == "add-expense" {
                        selectedTab = 1
                        showAddExpense = true
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
