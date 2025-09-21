import SwiftUI

struct ChecklistSheetView: View {
    @EnvironmentObject private var viewModel: TaskViewModel
    @Environment(\.presentationMode) var presentationMode
    
    let period: Period
    let date: Date
    let isRecoveryMode: Bool
    
    @State private var taskCompletions: [UUID: Bool] = [:]
    @State private var hasChanges = false
    
    private var tasksForPeriod: [(task: Task, completed: Bool)] {
        if isRecoveryMode {
            return viewModel.activeTasks
                .filter { $0.isApplicable(for: period) }
                .map { task in
                    let completed = task.id != nil ? (taskCompletions[task.id!] ?? false) : false
                    return (task: task, completed: completed)
                }
        } else {
            return viewModel.getTasksForToday(period: period)
        }
    }
    
    private var completionSummary: (completed: Int, total: Int) {
        let total = tasksForPeriod.count
        let completed = tasksForPeriod.filter { $0.completed }.count
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
                
                if hasChanges || isRecoveryMode {
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
                    
                    Text("Logging missed tasks")
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
        
        return VStack(spacing: 8) {
            HStack {
                Text("\(summary.completed) of \(summary.total) completed")
                    .font(.headline)
                
                Spacer()
                
                Text("\(Int((Double(summary.completed) / Double(summary.total)) * 100))%")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(summary.completed == summary.total ? .green : .primary)
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
                        .frame(width: CGFloat(summary.completed) / CGFloat(summary.total) * geometry.size.width, height: 8)
                        .foregroundColor(summary.completed == summary.total ? .green : .blue)
                        .cornerRadius(4)
                        .animation(.easeInOut(duration: 0.3), value: summary.completed)
                }
            }
            .frame(height: 8)
        }
    }
    
    private var checklistView: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(tasksForPeriod, id: \.task.id) { taskInfo in
                    taskRow(task: taskInfo.task, completed: taskInfo.completed)
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }
    
    private func taskRow(task: Task, completed: Bool) -> some View {
        HStack(spacing: 16) {
            // Completion Button
            Button {
                toggleTaskCompletion(task: task)
            } label: {
                Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(completed ? .green : .gray)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Task Title
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title ?? "Untitled Task")
                    .font(.body)
                    .strikethrough(completed)
                    .foregroundColor(completed ? .secondary : .primary)
                
                // TODO: Add streak info or last completed
            }
            
            Spacer()
            
            // Quick Action Buttons
            HStack(spacing: 12) {
                Button {
                    markAsSkipped(task: task)
                } label: {
                    Image(systemName: "xmark.circle")
                        .font(.title3)
                        .foregroundColor(.orange)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .animation(.easeInOut(duration: 0.2), value: completed)
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
        if isRecoveryMode {
            // Initialize all as false for recovery mode, only for applicable tasks
            for task in viewModel.activeTasks.filter({ $0.isApplicable(for: period) }) {
                if let id = task.id {
                    taskCompletions[id] = false
                }
            }
        }
    }
    
    private func toggleTaskCompletion(task: Task) {
        if isRecoveryMode {
            if let id = task.id {
                taskCompletions[id] = !(taskCompletions[id] ?? false)
            }
            hasChanges = true
        } else {
            let currentlyCompleted = task.isCompleted(for: date, period: period)
            viewModel.markTaskCompletion(task, for: date, period: period, completed: !currentlyCompleted)
            hasChanges = true
        }
    }
    
    private func markAsSkipped(task: Task) {
        if isRecoveryMode {
            if let id = task.id {
                taskCompletions[id] = false
            }
            hasChanges = true
        } else {
            viewModel.markTaskCompletion(task, for: date, period: period, completed: false)
            hasChanges = true
        }
    }
    
    private func saveChanges() {
        if isRecoveryMode {
            let completedTaskIds = Set(taskCompletions.compactMap { key, value in
                value ? key : nil
            })
            viewModel.logMissedTasks(for: date, period: period, completedTaskIds: completedTaskIds)
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