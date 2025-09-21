import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: TaskViewModel
    @EnvironmentObject private var notificationManager: NotificationManager
    @StateObject private var notificationDelegate = NotificationDelegate.shared
    
    @State private var selectedTab = 0
    @State private var showingChecklist = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Dashboard Tab
            DashboardView()
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Dashboard")
                }
                .tag(0)
            
            // Tasks Tab
            TaskManagementView()
                .tabItem {
                    Image(systemName: "checklist")
                    Text("Habits")
                }
                .tag(1)
            
            // Quick Notes Tab
            OneOffTodosView()
                .tabItem {
                    Image(systemName: "note.text")
                    Text("Notes")
                }
                .tag(2)
            
            // Weight Tracking Tab
            WeightTrackingView()
                .tabItem {
                    Image(systemName: "scalemass")
                    Text("Weight")
                }
                .tag(3)
            
            // Settings Tab
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(4)
        }
        .sheet(isPresented: $notificationDelegate.shouldPresentChecklist) {
            ChecklistSheetView(period: notificationDelegate.checklistPeriod)
        }
        .onAppear {
            setupNotifications()
        }
    }
    
    private func setupNotifications() {
        // Use completion handler approach for iOS 14 compatibility
        notificationManager.requestPermission { granted in
            if granted, let settings = viewModel.settings {
                notificationManager.scheduleHabitReminders(
                    morningTime: settings.morningReminderTime ?? Period.morning.defaultTime,
                    eveningTime: settings.eveningReminderTime ?? Period.evening.defaultTime
                )
            }
        }
    }
}

// MARK: - Task Management View

struct TaskManagementView: View {
    @EnvironmentObject private var viewModel: TaskViewModel
    @State private var showingAddTask = false
    @State private var newTaskTitle = ""
    
    var body: some View {
        NavigationView {
            List {
                if viewModel.activeTasks.isEmpty {
                    emptyStateView
                } else {
                    activeTasksSection
                }
            }
            .navigationTitle("My Habits")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddTask = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskViewWithPeriods(newTaskTitle: $newTaskTitle) { periods in
                if !newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    viewModel.addTask(title: newTaskTitle, periods: periods)
                    newTaskTitle = ""
                }
                showingAddTask = false
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text("No Habits Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Add your first habit to get started tracking your daily progress.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                showingAddTask = true
            } label: {
                Text("Add First Habit")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
        .padding(40)
    }
    
    private var activeTasksSection: some View {
        Section("Active Habits") {
            ForEach(viewModel.activeTasks, id: \.id) { task in
                TaskRowView(task: task)
            }
        }
    }
}

// MARK: - Task Row View

struct TaskRowView: View {
    @EnvironmentObject private var viewModel: TaskViewModel
    let task: Task
    
    @State private var showingEditSheet = false
    @State private var editedTitle: String = ""
    @State private var showingDeleteAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title ?? "Untitled Task")
                        .font(.body)
                        .fontWeight(.medium)
                    
                    HStack {
                        Text("Created \(task.created ?? Date(), style: .date)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // Show period indicators
                        HStack(spacing: 4) {
                            ForEach(Array(task.selectedPeriods), id: \.self) { period in
                                Text(period.displayName)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(period == .morning ? Color.blue.opacity(0.2) : Color.purple.opacity(0.2))
                                    .foregroundColor(period == .morning ? .blue : .purple)
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Completion rate for last 7 days
                let completionRate = task.completionRate(for: 7)
                Text("\(Int(completionRate * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(completionRateColor(completionRate).opacity(0.2))
                    .foregroundColor(completionRateColor(completionRate))
                    .cornerRadius(8)
            }
            
            // Quick completion indicators for today
            HStack(spacing: 16) {
                completionIndicator(period: .morning, task: task)
                completionIndicator(period: .evening, task: task)
            }
        }
        // Context menu for task actions
        .contextMenu {
            Button("Edit") {
                editedTitle = task.title ?? "Untitled Task"
                showingEditSheet = true
            }
            
            Button("Archive") {
                viewModel.archiveTask(task)
            }
            
            Divider()
            
            Button("Delete") {
                showingDeleteAlert = true
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditTaskView(
                taskTitle: $editedTitle,
                originalTitle: task.title ?? "Untitled Task"
            ) {
                if !editedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    viewModel.updateTask(task, title: editedTitle)
                }
                showingEditSheet = false
            }
        }
        .alert(isPresented: $showingDeleteAlert) {
            Alert(
                title: Text("Delete Habit"),
                message: Text("Are you sure you want to permanently delete \"\(task.title ?? "this habit")\"? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    viewModel.deleteTask(task)
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    private func completionIndicator(period: Period, task: Task) -> some View {
        let isCompleted = task.isCompleted(for: Date(), period: period)
        
        return HStack(spacing: 4) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .foregroundColor(isCompleted ? .green : .gray)
            
            Text(period.displayName)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private func completionRateColor(_ rate: Double) -> Color {
        switch rate {
        case 0.8...1.0:
            return .green
        case 0.5..<0.8:
            return .yellow
        default:
            return .red
        }
    }
}

// MARK: - Add Task View

struct AddTaskViewWithPeriods: View {
    @Binding var newTaskTitle: String
    let onSave: (Set<Period>) -> Void
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedPeriods: Set<Period> = [.morning, .evening]
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add New Habit")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("What habit would you like to track?")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Habit Name")
                        .font(.headline)
                    
                    TextField("e.g., Drink 8 glasses of water", text: $newTaskTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .submitLabel(.done)
                        .onSubmit {
                            onSave(selectedPeriods)
                        }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("When do you want to track this habit?")
                        .font(.headline)
                    
                    VStack(spacing: 8) {
                        PeriodSelectionRow(
                            title: "Morning", 
                            subtitle: "Track this habit in the morning",
                            period: .morning,
                            selectedPeriods: $selectedPeriods
                        )
                        
                        PeriodSelectionRow(
                            title: "Evening", 
                            subtitle: "Track this habit in the evening",
                            period: .evening,
                            selectedPeriods: $selectedPeriods
                        )
                    }
                    .padding(.vertical, 4)
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        onSave(selectedPeriods)
                    }
                    .disabled(newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedPeriods.isEmpty)
                }
            }
        }
    }
}

// MARK: - Period Selection Row

struct PeriodSelectionRow: View {
    let title: String
    let subtitle: String
    let period: Period
    @Binding var selectedPeriods: Set<Period>
    
    private var isSelected: Bool {
        selectedPeriods.contains(period)
    }
    
    var body: some View {
        Button {
            if isSelected {
                selectedPeriods.remove(period)
            } else {
                selectedPeriods.insert(period)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .blue : .gray)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Edit Task View

struct EditTaskView: View {
    @Binding var taskTitle: String
    let originalTitle: String
    let onSave: () -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Edit Habit")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Update your habit name")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Habit Name")
                        .font(.headline)
                    
                    TextField("Habit name", text: $taskTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .submitLabel(.done)
                        .onSubmit {
                            onSave()
                        }
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave()
                    }
                    .disabled(taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - OneOffTodos View

struct OneOffTodosView: View {
    @EnvironmentObject private var viewModel: TaskViewModel
    @State private var showingAddTodo = false
    @State private var newTodoTitle = ""
    
    var pendingTodos: [OneOffTodo] {
        viewModel.oneOffTodos.filter { $0.statusEnum == .pending }
    }
    
    var completedTodos: [OneOffTodo] {
        viewModel.oneOffTodos.filter { $0.statusEnum == .completed }
    }
    
    var failedTodos: [OneOffTodo] {
        viewModel.oneOffTodos.filter { $0.statusEnum == .failed }
    }
    
    var body: some View {
        NavigationView {
            List {
                if pendingTodos.isEmpty && completedTodos.isEmpty && failedTodos.isEmpty {
                    emptyStateView
                } else {
                    if !pendingTodos.isEmpty {
                        Section("To Do") {
                            ForEach(pendingTodos, id: \.id) { todo in
                                OneOffTodoRowView(todo: todo)
                            }
                        }
                    }
                    
                    if !completedTodos.isEmpty {
                        Section("Completed") {
                            ForEach(completedTodos, id: \.id) { todo in
                                OneOffTodoRowView(todo: todo)
                            }
                        }
                    }
                    
                    if !failedTodos.isEmpty {
                        Section("Failed") {
                            ForEach(failedTodos, id: \.id) { todo in
                                OneOffTodoRowView(todo: todo)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Quick Notes")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddTodo = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddTodo) {
            AddOneOffTodoView(newTodoTitle: $newTodoTitle) {
                if !newTodoTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    viewModel.addOneOffTodo(title: newTodoTitle)
                    newTodoTitle = ""
                }
                showingAddTodo = false
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "note.text")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text("No Quick Notes")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Add quick todos and mental notes that you can tick off without affecting your habit progress.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                showingAddTodo = true
            } label: {
                Text("Add First Note")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(12)
            }
        }
        .padding(40)
    }
}

// MARK: - OneOffTodo Row View

struct OneOffTodoRowView: View {
    @EnvironmentObject private var viewModel: TaskViewModel
    let todo: OneOffTodo
    
    @State private var showingDeleteAlert = false
    
    var body: some View {
        HStack {
            Button {
                viewModel.toggleOneOffTodo(todo)
            } label: {
                Image(systemName: todo.statusEnum.icon)
                    .font(.title2)
                    .foregroundColor(todo.statusEnum.color)
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(todo.title ?? "Untitled")
                    .font(.body)
                    .strikethrough(todo.statusEnum == .completed)
                    .foregroundColor(todo.statusEnum == .completed ? .secondary : .primary)
                
                Text("Added \(todo.created ?? Date(), style: .date)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .contextMenu {
            Button("Mark as Completed") {
                viewModel.setOneOffTodoStatus(todo, status: .completed)
            }
            
            Button("Mark as Failed") {
                viewModel.setOneOffTodoStatus(todo, status: .failed)
            }
            
            Button("Mark as Pending") {
                viewModel.setOneOffTodoStatus(todo, status: .pending)
            }
            
            Divider()
            
            Button("Delete") {
                showingDeleteAlert = true
            }
        }
        .alert(isPresented: $showingDeleteAlert) {
            Alert(
                title: Text("Delete Note"),
                message: Text("Are you sure you want to delete this note?"),
                primaryButton: .destructive(Text("Delete")) {
                    viewModel.deleteOneOffTodo(todo)
                },
                secondaryButton: .cancel()
            )
        }
    }
}

// MARK: - Add OneOffTodo View

struct AddOneOffTodoView: View {
    @Binding var newTodoTitle: String
    let onSave: () -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add Quick Note")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Add a quick todo or mental note")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Note")
                        .font(.headline)
                    
                    TextField("e.g., Call dentist, Buy groceries", text: $newTodoTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .submitLabel(.done)
                        .onSubmit {
                            onSave()
                        }
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        onSave()
                    }
                    .disabled(newTodoTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Weight Tracking View

struct WeightTrackingView: View {
    @EnvironmentObject private var viewModel: TaskViewModel
    @State private var showingAddWeight = false
    @State private var newWeight = ""
    @State private var selectedDate = Date()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Current weight section
                    currentWeightSection
                    
                    // Weight chart section
                    weightChartSection
                    
                    // Recent entries section
                    recentEntriesSection
                }
                .padding()
            }
            .navigationTitle("Weight Tracker")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddWeight = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddWeight) {
            AddWeightEntryView(newWeight: $newWeight, selectedDate: $selectedDate) {
                if let weight = Double(newWeight), weight > 0 {
                    viewModel.addWeightEntry(weight: weight, date: selectedDate)
                    newWeight = ""
                    selectedDate = Date()
                }
                showingAddWeight = false
            }
        }
    }
    
    // MARK: - Current Weight Section
    
    private var currentWeightSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Current Weight")
                .font(.title2)
                .fontWeight(.bold)
            
            if let latestEntry = viewModel.weightEntries.first {
                HStack {
                    VStack(alignment: .leading) {
                        Text("\(latestEntry.weight, specifier: "%.1f") kgs")
                            .font(.title)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                        
                        Text("Last updated: \(latestEntry.date ?? Date(), style: .date)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if viewModel.weightEntries.count > 1 {
                        let previousEntry = viewModel.weightEntries[1]
                        let change = latestEntry.weight - previousEntry.weight
                        HStack(spacing: 4) {
                            Image(systemName: change >= 0 ? "arrow.up" : "arrow.down")
                                .font(.caption)
                                .foregroundColor(change >= 0 ? .red : .green)
                            
                            Text("\(abs(change), specifier: "%.1f") kgs")
                                .font(.caption)
                                .foregroundColor(change >= 0 ? .red : .green)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "scalemass")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("No weight entries yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Add your first weight entry to start tracking your progress.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button {
                        showingAddWeight = true
                    } label: {
                        Text("Add Weight Entry")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                }
                .padding(40)
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Weight Chart Section
    
    private var weightChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Progress Chart")
                .font(.title2)
                .fontWeight(.bold)
            
            let chartData = viewModel.getWeightEntriesForChart()
            
            if chartData.count >= 2 {
                WeightLineChart(data: chartData)
                    .frame(height: 200)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
            } else {
                Text("Add at least 2 weight entries to see your progress chart")
                    .foregroundColor(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGroupedBackground))
                    .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Recent Entries Section
    
    private var recentEntriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Entries")
                .font(.title2)
                .fontWeight(.bold)
            
            if viewModel.weightEntries.isEmpty {
                Text("No entries yet")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGroupedBackground))
                    .cornerRadius(12)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(viewModel.weightEntries.prefix(10).enumerated()), id: \.element.id) { index, entry in
                        WeightEntryRowView(entry: entry)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - Weight Entry Row View

struct WeightEntryRowView: View {
    @EnvironmentObject private var viewModel: TaskViewModel
    let entry: WeightEntry
    
    @State private var showingDeleteAlert = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(entry.weight, specifier: "%.1f") kgs")
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(entry.date ?? Date(), style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .contextMenu {
            Button("Delete") {
                showingDeleteAlert = true
            }
        }
        .alert(isPresented: $showingDeleteAlert) {
            Alert(
                title: Text("Delete Weight Entry"),
                message: Text("Are you sure you want to delete this weight entry?"),
                primaryButton: .destructive(Text("Delete")) {
                    viewModel.deleteWeightEntry(entry)
                },
                secondaryButton: .cancel()
            )
        }
    }
}

// MARK: - Add Weight Entry View

struct AddWeightEntryView: View {
    @Binding var newWeight: String
    @Binding var selectedDate: Date
    let onSave: () -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add Weight Entry")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Track your daily weight")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
                
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Weight (kgs)")
                            .font(.headline)
                        
                        TextField("e.g., 150.5", text: $newWeight)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                            .submitLabel(.done)
                            .onSubmit {
                                onSave()
                            }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Date")
                            .font(.headline)
                        
                        DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                            .datePickerStyle(CompactDatePickerStyle())
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        onSave()
                    }
                    .disabled(newWeight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || Double(newWeight) == nil || Double(newWeight)! <= 0)
                }
            }
        }
    }
}

// MARK: - Weight Line Chart

struct WeightLineChart: View {
    let data: [(date: Date, weight: Double)]
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Weight Progress Chart")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if data.count >= 2 {
                let firstWeight = data.last?.weight ?? 0
                let lastWeight = data.first?.weight ?? 0
                let change = lastWeight - firstWeight
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Starting Weight")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(firstWeight, specifier: "%.1f") kgs")
                            .font(.body)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    VStack {
                        Text("Change")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(spacing: 4) {
                            Image(systemName: change >= 0 ? "arrow.up" : "arrow.down")
                                .font(.caption)
                                .foregroundColor(change >= 0 ? .red : .green)
                            Text("\(abs(change), specifier: "%.1f") kgs")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(change >= 0 ? .red : .green)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Current Weight")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(lastWeight, specifier: "%.1f") kgs")
                            .font(.body)
                            .fontWeight(.medium)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            } else {
                Text("Not enough data for chart")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }
}

extension DateFormatter {
    static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter
    }()
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(TaskViewModel.createPreviewViewModel())
            .environmentObject(NotificationManager.shared)
    }
}
