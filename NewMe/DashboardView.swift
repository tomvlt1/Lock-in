import SwiftUI
import Foundation

struct DashboardView: View {
    @EnvironmentObject private var viewModel: TaskViewModel
    @State private var showingChecklist = false
    @State private var selectedPeriod: Period = .morning
    @State private var recoveryPeriod: Period?
    @State private var recoveryDate: Date?
    @State private var isShowingRecoveryChecklist = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Edit Yesterday
                    editYesterdaySection
                    
                    // Quick actions
                    quickActionsSection
                    
                    // Weekly + Today
                    completionChartSection
                    
                    // 30-Day Progress
                    heatMapSection
                    
                    // Most Skipped
                    mostSkippedSection
                }
                .padding()
            }
            .navigationTitle("Habit Tracker")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink("Settings") {
                        SettingsView()
                    }
                }
            }
        }
        .sheet(isPresented: $showingChecklist) {
            if isShowingRecoveryChecklist {
                ChecklistSheetView(
                    period: recoveryPeriod!,
                    date: recoveryDate!,
                    isRecoveryMode: true
                )
            } else {
                ChecklistSheetView(period: selectedPeriod)
            }
        }
    }
    
    // MARK: - Quick Actions
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Check-in")
                .font(.title2)
                .fontWeight(.bold)
            
            HStack(spacing: 16) {
                quickActionButton(
                    title: "Morning",
                    subtitle: morningCompletionText,
                    period: .morning,
                    color: .blue
                )
                
                quickActionButton(
                    title: "Evening",
                    subtitle: eveningCompletionText,
                    period: .evening,
                    color: .purple
                )
            }
        }
    }
    
    private func quickActionButton(title: String, subtitle: String, period: Period, color: Color) -> some View {
        Button {
            selectedPeriod = period
            isShowingRecoveryChecklist = false
            showingChecklist = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Edit Yesterday
    
    private var editYesterdaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Edit Yesterday")
                .font(.title3)
                .fontWeight(.semibold)
            HStack(spacing: 12) {
                Button {
                    recoveryPeriod = .morning
                    recoveryDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())
                    isShowingRecoveryChecklist = true
                    showingChecklist = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sunrise")
                            .foregroundColor(.blue)
                        Text("Morning")
                            .font(.subheadline)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button {
                    recoveryPeriod = .evening
                    recoveryDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())
                    isShowingRecoveryChecklist = true
                    showingChecklist = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "moon")
                            .foregroundColor(.purple)
                        Text("Evening")
                            .font(.subheadline)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    // MARK: - Weekly + Today
    
    private var completionChartSection: some View {
        // Precompute outside the builder to reduce complexity
        let chartData = viewModel.getCompletionRatesForLast30Days()
        let weeklyData = Array(chartData.suffix(7))
        let weeklyAverage: Double = {
            guard !weeklyData.isEmpty else { return 0 }
            let sum = weeklyData.map { $0.rate }.reduce(0, +)
            return sum / Double(weeklyData.count)
        }()
        let todayRate: Double = chartData.last?.rate ?? 0
        
        return VStack(alignment: .leading, spacing: 16) {
            Text("Weekly Progress")
                .font(.title2)
                .fontWeight(.bold)
            
            if !chartData.isEmpty {
                VStack(spacing: 12) {
                    // Clean weekly sparkline
                    WeeklySparkBarsView(
                        weeklyData: weeklyData,
                        weeklyAverage: weeklyAverage,
                        barColor: { rate in
                            // Softer colors for a cleaner look
                            switch rate {
                            case 0.8...1.0: return Color.green.opacity(0.85)
                            case 0.5..<0.8: return Color.orange.opacity(0.85)
                            default: return Color.red.opacity(0.85)
                            }
                        }
                    )
                    
                    // Today + streak compact card
                    DailyStreakView(
                        currentStreak: getCurrentStreak(),
                        todayRate: todayRate,
                        progressColor: progressColor(for:)
                    )
                }
            } else {
                Text("No data available yet")
                    .foregroundColor(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGroupedBackground))
                    .cornerRadius(12)
            }
        }
    }
    
    // MARK: - 30-Day Progress
    
    private var heatMapSection: some View {
        let chartData = viewModel.getCompletionRatesForLast30Days()
        
        return VStack(alignment: .leading, spacing: 16) {
            Text("30-Day Progress")
                .font(.title2)
                .fontWeight(.bold)
            
            if !chartData.isEmpty {
                VStack(spacing: 12) {
                    ThirtyDayAreaLineChartView(
                        chartData: chartData,
                        lineColor: Color.blue.opacity(0.9),
                        gradient: LinearGradient(
                            gradient: Gradient(colors: [Color.blue.opacity(0.25), Color.blue.opacity(0.05)]),
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        pointColor: { rate in
                            // Subtle point color
                            Color.blue.opacity(0.9)
                        }
                    )
                    .frame(height: 220)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    
                    XAxisLabelsView(chartData: chartData)
                        .padding(.horizontal, 20)
                }
            } else {
                Text("No data available yet")
                    .foregroundColor(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGroupedBackground))
                    .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Most Skipped Tasks
    
    private var mostSkippedSection: some View {
        let skippedTasks = viewModel.getMostSkippedTasks().prefix(3)
        
        return VStack(alignment: .leading, spacing: 16) {
            Text("Most Skipped Habits")
                .font(.title2)
                .fontWeight(.bold)
            
            if skippedTasks.isEmpty {
                Text("Great job! No frequently skipped habits.")
                    .foregroundColor(.green)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(skippedTasks.enumerated()), id: \.element.task.id) { index, taskInfo in
                        HStack {
                            Text("\(index + 1).")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .frame(width: 20)
                            
                            Text(taskInfo.task.title ?? "Untitled Task")
                                .font(.body)
                            
                            Spacer()
                            
                            Text("\(Int(taskInfo.skipRate * 100))%")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.15))
                                .foregroundColor(.orange)
                                .cornerRadius(8)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private var morningCompletionText: String {
        let tasks = viewModel.getTasksForToday(period: .morning)
        let completed = tasks.filter { $0.completed }.count
        let total = tasks.count
        
        if total == 0 {
            return "No morning habits"
        } else if completed == total {
            return "All done! ✅"
        } else {
            return "\(completed) of \(total) completed"
        }
    }
    
    private var eveningCompletionText: String {
        let tasks = viewModel.getTasksForToday(period: .evening)
        let completed = tasks.filter { $0.completed }.count
        let total = tasks.count
        
        if total == 0 {
            return "No evening habits"
        } else if completed == total {
            return "All done! ✅"
        } else {
            return "\(completed) of \(total) completed"
        }
    }
    
    private func progressColor(for rate: Double) -> Color {
        switch rate {
        case 0.8...1.0:
            return .green
        case 0.5..<0.8:
            return .orange
        default:
            return .red
        }
    }
    
    private func getCurrentStreak() -> Int {
        let chartData = viewModel.getCompletionRatesForLast30Days()
        var streak = 0
        
        for dataPoint in chartData.reversed() {
            if dataPoint.rate > 0.7 { // Consider 70%+ as maintaining streak
                streak += 1
            } else {
                break
            }
        }
        
        return streak
    }
}

// MARK: - Extracted Subviews

// Cleaner weekly spark bars with subtle grid and an average badge.
private struct WeeklySparkBarsView: View {
    let weeklyData: [(date: Date, rate: Double)]
    let weeklyAverage: Double
    let barColor: (Double) -> Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(Int(weeklyAverage * 100))% avg")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                
                Spacer()
            }
            
            GeometryReader { geometry in
                let height = geometry.size.height
                let width = geometry.size.width
                let barWidth = max(12, (width - 40) / CGFloat(max(weeklyData.count, 1)) - 6)
                
                ZStack {
                    // Subtle horizontal grid (3 lines)
                    VStack(spacing: 0) {
                        ForEach(0..<3) { _ in
                            Rectangle()
                                .fill(Color.gray.opacity(0.08))
                                .frame(height: 1)
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 10)
                    
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(weeklyData, id: \.date) { point in
                            let barHeight = CGFloat(point.rate) * (height - 20)
                            VStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(barColor(point.rate))
                                    .frame(width: barWidth, height: max(4, barHeight))
                                
                                Text(DateFormatter.weekdayFormatter.string(from: point.date))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 4)
                }
            }
            .frame(height: 120)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

private struct DailyStreakView: View {
    let currentStreak: Int
    let todayRate: Double
    let progressColor: (Double) -> Color
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Current Streak")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(currentStreak) days")
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("Today")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(Int(todayRate * 100))%")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(progressColor(todayRate))
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// Clean 30-day line with soft gradient fill and minimal axes/grid.
private struct ThirtyDayAreaLineChartView: View {
    let chartData: [(date: Date, rate: Double)]
    let lineColor: Color
    let gradient: LinearGradient
    let pointColor: (Double) -> Color
    
    var body: some View {
        GeometryReader { geometry in
            let chartHeight = geometry.size.height - 40
            let chartWidth = geometry.size.width - 40
            
            ZStack {
                // Subtle grid: 100%, 50%, 0%
                VStack(spacing: 0) {
                    ForEach([1.0, 0.5, 0.0], id: \.self) { frac in
                        HStack {
                            Text("\(Int(frac * 100))%")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 30, alignment: .leading)
                            Rectangle()
                                .fill(Color.gray.opacity(0.08))
                                .frame(height: 1)
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                
                // Area fill under the line
                areaPath(in: chartWidth, chartHeight: chartHeight)
                    .fill(gradient)
                    .opacity(0.8)
                
                // Line
                linePath(in: chartWidth, chartHeight: chartHeight)
                    .stroke(lineColor, lineWidth: 2)
                
                // Points (subtle)
                let points = positions(in: chartWidth, chartHeight: chartHeight)
                ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                    Circle()
                        .fill(pointColor(chartData[index].rate))
                        .frame(width: 5, height: 5)
                        .position(point)
                }
            }
        }
    }
    
    private func positions(in chartWidth: CGFloat, chartHeight: CGFloat) -> [CGPoint] {
        guard !chartData.isEmpty else { return [] }
        return chartData.enumerated().map { index, dp in
            CGPoint(
                x: 20 + (CGFloat(index) / CGFloat(max(chartData.count - 1, 1))) * chartWidth,
                y: chartHeight - (CGFloat(dp.rate) * chartHeight) + 20
            )
        }
    }
    
    private func linePath(in chartWidth: CGFloat, chartHeight: CGFloat) -> Path {
        var path = Path()
        let pts = positions(in: chartWidth, chartHeight: chartHeight)
        guard let first = pts.first else { return path }
        path.move(to: first)
        for p in pts.dropFirst() {
            path.addLine(to: p)
        }
        return path
    }
    
    private func areaPath(in chartWidth: CGFloat, chartHeight: CGFloat) -> Path {
        var path = Path()
        let pts = positions(in: chartWidth, chartHeight: chartHeight)
        guard let first = pts.first, let last = pts.last else { return path }
        path.move(to: CGPoint(x: first.x, y: chartHeight + 20))
        for p in pts {
            path.addLine(to: p)
        }
        path.addLine(to: CGPoint(x: last.x, y: chartHeight + 20))
        path.closeSubpath()
        return path
    }
}

private struct XAxisLabelsView: View {
    let chartData: [(date: Date, rate: Double)]
    
    var body: some View {
        HStack {
            ForEach(Array(chartData.enumerated().filter { $0.offset % 5 == 0 }), id: \.offset) { index, dataPoint in
                Text(DateFormatter.dayFormatter.string(from: dataPoint.date))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                if index < chartData.count - 5 { Spacer() }
            }
        }
    }
}

extension DateFormatter {
    static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter
    }()
    
    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter
    }()
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
            .environmentObject(TaskViewModel.createPreviewViewModel())
    }
}
