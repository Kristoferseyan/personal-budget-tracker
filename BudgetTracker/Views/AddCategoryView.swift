import SwiftUI
import SwiftData

struct AddCategoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var selectedIcon: String = "tag.fill"
    @State private var selectedColor: String = "blue"

    private let iconColumns = [
        GridItem(.adaptive(minimum: 50))
    ]

    private let colorColumns = [
        GridItem(.adaptive(minimum: 44))
    ]

    var body: some View {
        NavigationStack {
            Form {
                // Preview
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: selectedIcon)
                                .font(.system(size: 32))
                                .foregroundColor(colorFromName(selectedColor))
                            Text(name.isEmpty ? "Category Name" : name)
                                .font(.headline)
                                .foregroundColor(name.isEmpty ? .secondary : .primary)
                        }
                        .padding()
                        Spacer()
                    }
                }

                // Name
                Section("Name") {
                    TextField("e.g., Pet Supplies, Snacks", text: $name)
                }

                // Icon Picker
                Section("Icon") {
                    LazyVGrid(columns: iconColumns, spacing: 12) {
                        ForEach(CategoryIcons.all, id: \.icon) { item in
                            IconButton(
                                icon: item.icon,
                                isSelected: selectedIcon == item.icon,
                                color: colorFromName(selectedColor)
                            ) {
                                selectedIcon = item.icon
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Color Picker
                Section("Color") {
                    LazyVGrid(columns: colorColumns, spacing: 12) {
                        ForEach(CategoryColors.all, id: \.name) { item in
                            ColorButton(
                                colorName: item.name,
                                isSelected: selectedColor == item.name
                            ) {
                                selectedColor = item.name
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCategory()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func saveCategory() {
        let category = CustomCategory(
            name: name.trimmingCharacters(in: .whitespaces),
            icon: selectedIcon,
            colorName: selectedColor
        )
        modelContext.insert(category)
        dismiss()
    }

    private func colorFromName(_ name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        case "purple": return .purple
        case "pink": return .pink
        case "yellow": return .yellow
        case "teal": return .teal
        case "indigo": return .indigo
        case "brown": return .brown
        default: return .gray
        }
    }
}

// MARK: - Icon Button
struct IconButton: View {
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(isSelected ? color.opacity(0.2) : Color(.systemGray6))
                .foregroundColor(isSelected ? color : .primary)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? color : .clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Color Button
struct ColorButton: View {
    let colorName: String
    let isSelected: Bool
    let action: () -> Void

    private var color: Color {
        switch colorName {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        case "purple": return .purple
        case "pink": return .pink
        case "yellow": return .yellow
        case "teal": return .teal
        case "indigo": return .indigo
        case "brown": return .brown
        default: return .gray
        }
    }

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 36, height: 36)
                .overlay(
                    Circle()
                        .stroke(Color.primary, lineWidth: isSelected ? 3 : 0)
                        .padding(2)
                )
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .opacity(isSelected ? 1 : 0)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AddCategoryView()
        .modelContainer(for: CustomCategory.self, inMemory: true)
}
