import SwiftUI

struct ProgressBarView: View {
    let current: Double
    let goal: Double
    var showPercentage: Bool = true
    var height: CGFloat = 24

    private var progress: Double {
        min(current / goal, 1.0)
    }

    private var percentage: Int {
        Int(progress * 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(Color.green.opacity(0.2))
                        .frame(height: height)

                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(
                            LinearGradient(
                                colors: [Color.green, Color.green.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: height)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: height)

            if showPercentage {
                HStack {
                    Text("\(percentage)%")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)

                    Spacer()

                    Text("\(current.asPHP) / \(goal.asPHP)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Large Progress Display
struct LargeProgressView: View {
    let current: Double
    let goal: Double

    private var progress: Double {
        min(current / goal, 1.0)
    }

    private var percentage: Int {
        Int(progress * 100)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("\(percentage)%")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundColor(.green)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.5), value: percentage)

            VStack(spacing: 4) {
                Text(current.asPHP)
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)

                Text("of \(goal.asPHP) goal")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            ProgressBarView(current: current, goal: goal, showPercentage: false, height: 16)
                .padding(.horizontal)
        }
        .padding()
    }
}

#Preview {
    VStack(spacing: 40) {
        LargeProgressView(current: 10725, goal: 80000)

        ProgressBarView(current: 25000, goal: 80000)
            .padding()
    }
}
