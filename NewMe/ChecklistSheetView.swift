import SwiftUI

struct ChecklistSheetView: View {
    @EnvironmentObject private var viewModel: TaskViewModel
    @Environment(\.presentationMode) var presentationMode
    
    let period: Period
    let date: Date
    let isRecoveryMode: Bool
    
    @State private var taskProgress: [UUID: Int] = [:]
    @State private var hasChanges = false
    
    private var tasksForPeriod: [Task] {
        let baseTasks = viewModel.activeTasks.filter { $0.isApplicable(for: period) }
        let today = Calendar.current.startOfDay(for: date)
        
        return baseTasks.sorted { first, second in
            let firstComplete = taskIsFullyComplete(first, referenceDate: today)
            let secondComplete = taskIsFullyComplete(second, referenceDate: today)
            
            if firstComplete == secondComplete {
                let firstTitle = first.title ?? ""
                let secondTitle = second.title ?? ""
                return firstTitle.localizedCaseInsensitiveCompare(secondTitle) == .orderedAscending
            }
            
            // Incomplete tasks should appear before completed ones
            return !firstComplete && secondComplete
        }
    }
    
    private var completionSummary: (completedUnits: Double, total: Int) {
        let total = tasksForPeriod.count
        let completed = tasksForPeriod.reduce(0.0) { partial, task in
            let required = max(1, task.weightEnum.requiredUnits)
            let progress = Double(progressValue(for: task)) / Double(required)
            return partial + min(1.0, progress)
        }
        return (completed, total)
    }
    
    init(period: Period, date: Date = Date(), isRecoveryMode: Bool = false) {
        self.period = period
        self.date = date
        self.isRecoveryMode = isRecoveryMode
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerView
                
                if tasksForPeriod.isEmpty {
                    emptyStateView
                } else {
                    checklistView
                }
                
                Spacer()
                
                if isRecoveryMode {
                    saveButton
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .onAppear {
            initializeCompletions()
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            // Period and Date
            VStack(spacing: 4) {
                Text(period.displayName)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text(formattedDate)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Recovery Mode Banner
            if isRecoveryMode {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.orange)
                    
                    Text("Editing previous day")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
            
            // Progress Indicator
            if !tasksForPeriod.isEmpty {
                progressIndicator
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
    
    private var progressIndicator: some View {
        let summary = completionSummary
        let ratio = summary.total > 0 ? summary.completedUnits / Double(summary.total) : 0
       
        return VStack(spacing: 8) {
            HStack {
                Text("\(String(format: "%.1f", summary.completedUnits)) of \(summary.total) completed")
                    .font(.headline)
                
                Spacer()
                
                Text("\(Int(ratio * 100))%")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(ratio >= 1.0 ? .green : .primary)
            }
            
            // iOS 13 compatible progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .frame(width: geometry.size.width, height: 8)
                        .opacity(0.3)
                        .foregroundColor(Color.gray)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .frame(width: CGFloat(ratio) * geometry.size.width, height: 8)
                        .foregroundColor(ratio >= 1.0 ? .green : .blue)
                        .cornerRadius(4)
                        .animation(.easeInOut(duration: 0.3), value: ratio)
                }
            }
            .frame(height: 8)
        }
    }
    
    private var checklistView: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(tasksForPeriod, id: \.id) { task in
                    taskRow(task: task)
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }
    
    private func taskRow(task: Task) -> some View {
        let required = task.weightEnum.requiredUnits
        let currentValue = progressValue(for: task)
        let binding = Binding<Double>(
            get: { Double(progressValue(for: task)) },
            set: { newValue in
                handleProgressChange(task: task, newValue: Int(newValue))
            }
        )
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title ?? "Untitled Task")
                        .font(.headline)
                    
                    Text("\(task.categoryEnum.displayName) • \(task.weightEnum.displayName) weight")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("\(currentValue)/\(required)")
                    .font(.caption)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(currentValue >= required ? Color.green.opacity(0.15) : Color.gray.opacity(0.15))
                    .cornerRadius(8)
            }
            
            Slider(value: binding, in: 0...Double(required), step: 1)
                .accentColor(task.categoryEnum.color)
            
            HStack {
                let remaining = max(0, required - currentValue)
                Text(remaining == 0 ? "Complete" : "Need \(remaining) more")
                    .font(.caption)
                    .foregroundColor(currentValue >= required ? .green : .secondary)
                
                Spacer()
                
                Button("Reset") {
                    handleProgressChange(task: task, newValue: 0)
                }
                .font(.caption)
                .foregroundColor(.orange)
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 64))
                .foregroundColor(.green)
            
            Text("No habits to track")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Add some habits in the main screen to get started!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
    
    private var saveButton: some View {
        Button {
            saveChanges()
            presentationMode.wrappedValue.dismiss()
        } label: {
            Text(isRecoveryMode ? "Save Recovery Log" : "Save Changes")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Computed Properties
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    // MARK: - Actions
    
    private func initializeCompletions() {
        guard taskProgress.isEmpty else { return }
        let tasks = viewModel.activeTasks.filter { $0.isApplicable(for: period) }
        for task in tasks {
            guard let id = task.id else { continue }
            let current = viewModel.currentProgress(for: task, date: date, period: period)
            taskProgress[id] = current
        }
    }
    
    private func progressValue(for task: Task) -> Int {
        guard let id = task.id else { return 0 }
        return taskProgress[id] ?? 0
    }
    
    private func taskIsFullyComplete(_ task: Task, referenceDate: Date) -> Bool {
        let required = task.weightEnum.requiredUnits
        if let id = task.id, let cached = taskProgress[id] {
            return cached >= required
        }
        // Fallback if progress cache is missing
        return viewModel.currentProgress(for: task, date: referenceDate, period: period) >= required
    }
    
    private func handleProgressChange(task: Task, newValue: Int) {
        guard let id = task.id else { return }
        let clamped = max(0, min(task.weightEnum.requiredUnits, newValue))
        taskProgress[id] = clamped
        
        if isRecoveryMode {
            hasChanges = true
        } else {
            viewModel.setTaskProgress(task, for: date, period: period, progressUnits: clamped)
        }
    }
    
    private func saveChanges() {
        if isRecoveryMode {
            let updates: [(task: Task, progressUnits: Int)] = tasksForPeriod.compactMap { task in
                guard let id = task.id else { return nil }
                let value = taskProgress[id] ?? 0
                return (task: task, progressUnits: value)
            }
            viewModel.bulkSetTaskProgress(for: date, period: period, updates: updates)
            hasChanges = false
        }
    }
}

// MARK: - Preview Support

struct ChecklistSheetView_Previews: PreviewProvider {
    static var previews: some View {
        ChecklistSheetView(period: .morning)
            .environmentObject(TaskViewModel.createPreviewViewModel())
    }
}
