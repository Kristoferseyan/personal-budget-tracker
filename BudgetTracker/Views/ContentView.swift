import SwiftUI
import SwiftData

struct ContentView: View {
    @Binding var selectedTab: Int
    @Binding var showAddExpense: Bool

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.pie.fill")
                }
                .tag(0)

            ExpensesView(showAddExpense: $showAddExpense)
                .tabItem {
                    Label("Expenses", systemImage: "creditcard.fill")
                }
                .tag(1)

            WishlistView()
                .tabItem {
                    Label("Wishlist", systemImage: "gift.fill")
                }
                .tag(2)

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
                .tag(3)
        }
        .tint(.green)
    }
}

#Preview {
    ContentView(selectedTab: .constant(0), showAddExpense: .constant(false))
        .modelContainer(for: [Week.self, Expense.self, CustomCategory.self], inMemory: true)
}
