import SwiftUI
import Foundation

struct DashboardView: View {
    @EnvironmentObject private var viewModel: TaskViewModel
    @State private var showingChecklist = false
    @State private var selectedPeriod: Period = .morning
    @State private var showingRecoveryBanner = false
    @State private var recoveryPeriod: Period?
    @State private var recoveryDate: Date?
    @State private var isShowingRecoveryChecklist = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    recoveryBannerView
                    
                    quickActionsSection
                    
                    completionChartSection
                    
                    heatMapSection
                    
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
        .onAppear {
            checkForRecovery()
        }
    }
    
    // MARK: - Recovery Banner
    
    private var recoveryBannerView: some View {
        Group {
            if showingRecoveryBanner,
               let period = recoveryPeriod,
               let _ = recoveryDate {
                
                Button {
                    isShowingRecoveryChecklist = true
                    showingChecklist = true
                } label: {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Log missed tasks?")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("Tap to log your \(period.displayName.lowercased()) habits")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.orange)
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
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
    
    // MARK: - Completion Chart
    
    private var completionChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Daily Progress")
                .font(.title2)
                .fontWeight(.bold)
            
            let chartData = viewModel.getCompletionRatesForLast30Days()
            let _ = viewModel.getSevenDayMovingAverage()
            
            if !chartData.isEmpty {
                VStack(spacing: 16) {
                    // Weekly summary
                    let weeklyData = Array(chartData.suffix(7))
                    HStack {
                        VStack(alignment: .leading) {
                            Text("This Week")
                                .font(.headline)
                            Text("\(Int(weeklyData.map{$0.rate}.reduce(0, +) / Double(weeklyData.count) * 100))% avg")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            ForEach(weeklyData, id: \.date) { dataPoint in
                                VStack {
                                    Rectangle()
                                        .fill(progressColor(for: dataPoint.rate))
                                        .frame(width: 20, height: CGFloat(dataPoint.rate * 80))
                                        .cornerRadius(2)
                                    
                                    Text(DateFormatter.weekdayFormatter.string(from: dataPoint.date))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    
                    // Daily streak info
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Current Streak")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(getCurrentStreak()) days")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Today")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(Int((chartData.last?.rate ?? 0) * 100))%")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(progressColor(for: chartData.last?.rate ?? 0))
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
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
    
    // MARK: - Line Chart
    
    private var heatMapSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("30-Day Progress")
                .font(.title2)
                .fontWeight(.bold)
            
            let chartData = viewModel.getCompletionRatesForLast30Days()
            
            if !chartData.isEmpty {
                VStack(spacing: 12) {
                    // Line chart
                    GeometryReader { geometry in
                        let maxRate = chartData.map { $0.rate }.max() ?? 1.0
                        let chartHeight = geometry.size.height - 40
                        let chartWidth = geometry.size.width - 40
                        
                        ZStack {
                            // Background grid
                            VStack(spacing: 0) {
                                ForEach(0..<5) { _ in
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.1))
                                        .frame(height: 1)
                                    Spacer()
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            // Y-axis labels
                            HStack {
                                VStack(spacing: 0) {
                                    ForEach([100, 75, 50, 25, 0], id: \.self) { percentage in
                                        Text("\(percentage)%")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        if percentage > 0 { Spacer() }
                                    }
                                }
                                .frame(width: 30)
                                
                                Spacer()
                            }
                            
                            // Line chart path
                            Path { path in
                                guard !chartData.isEmpty else { return }
                                
                                let points = chartData.enumerated().map { index, dataPoint in
                                    CGPoint(
                                        x: 20 + (CGFloat(index) / CGFloat(chartData.count - 1)) * chartWidth,
                                        y: chartHeight - (CGFloat(dataPoint.rate) * chartHeight) + 20
                                    )
                                }
                                
                                if let firstPoint = points.first {
                                    path.move(to: firstPoint)
                                    for point in points.dropFirst() {
                                        path.addLine(to: point)
                                    }
                                }
                            }
                            .stroke(Color.blue, lineWidth: 2)
                            
                            // Data points
                            ForEach(Array(chartData.enumerated()), id: \.offset) { index, dataPoint in
                                Circle()
                                    .fill(progressColor(for: dataPoint.rate))
                                    .frame(width: 6, height: 6)
                                    .position(
                                        x: 20 + (CGFloat(index) / CGFloat(chartData.count - 1)) * chartWidth,
                                        y: chartHeight - (CGFloat(dataPoint.rate) * chartHeight) + 20
                                    )
                            }
                        }
                    }
                    .frame(height: 200)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    
                    // X-axis labels (show every 5th day)
                    HStack {
                        ForEach(Array(chartData.enumerated().filter { $0.offset % 5 == 0 }), id: \.offset) { index, dataPoint in
                            Text(DateFormatter.dayFormatter.string(from: dataPoint.date))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            if index < chartData.count - 5 { Spacer() }
                        }
                    }
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
        VStack(alignment: .leading, spacing: 16) {
            Text("Most Skipped Habits")
                .font(.title2)
                .fontWeight(.bold)
            
            let skippedTasks = viewModel.getMostSkippedTasks().prefix(3)
            
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
                                .background(Color.orange.opacity(0.2))
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
    
    private func heatMapColor(for rate: Double) -> Color {
        switch rate {
        case 0:
            return Color(.systemFill)
        case 0.01...0.33:
            return Color.red.opacity(0.6)
        case 0.34...0.66:
            return Color.yellow.opacity(0.6)
        case 0.67...0.99:
            return Color.green.opacity(0.6)
        case 1.0:
            return Color.green
        default:
            return Color(.systemFill)
        }
    }
    
    private func checkForRecovery() {
        let recoveryInfo = NotificationManager.shared.shouldShowRecoveryBanner()
        showingRecoveryBanner = recoveryInfo.show
        recoveryPeriod = recoveryInfo.period
        recoveryDate = recoveryInfo.date
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
