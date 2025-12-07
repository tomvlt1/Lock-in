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
            
            // Metrics Tab (Weight + Plank)
            MetricsView()
                .tabItem {
                    Image(systemName: "gauge")
                    Text("Metrics")
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
            AddTaskViewWithPeriods(newTaskTitle: $newTaskTitle) { periods, category, weight in
                if !newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    viewModel.addTask(
                        title: newTaskTitle,
                        periods: periods,
                        category: category,
                        weight: weight
                    )
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
            ForEach(sortedActiveTasks, id: \.id) { task in
                TaskRowView(task: task)
            }
        }
    }

    private var sortedActiveTasks: [Task] {
        let today = Calendar.current.startOfDay(for: Date())
        return viewModel.activeTasks.sorted { first, second in
            let firstComplete = first.isFullyCompleted(on: today)
            let secondComplete = second.isFullyCompleted(on: today)
            
            if firstComplete == secondComplete {
                let firstTitle = first.title ?? ""
                let secondTitle = second.title ?? ""
                return firstTitle.localizedCaseInsensitiveCompare(secondTitle) == .orderedAscending
            }
            
            // Incomplete tasks should appear first.
            return !firstComplete && secondComplete
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
                    
                    HStack(spacing: 8) {
                        Label(task.categoryEnum.displayName, systemImage: "tag")
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(task.categoryEnum.color.opacity(0.15))
                            .foregroundColor(task.categoryEnum.color)
                            .cornerRadius(6)
                        
                        Text("\(task.weightEnum.displayName) weight")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
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
                originalTitle: task.title ?? "Untitled Task",
                task: task
            ) { periods, category, weight in
                if !editedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    viewModel.updateTask(
                        task,
                        title: editedTitle,
                        periods: periods,
                        category: category,
                        weight: weight
                    )
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
        let today = Calendar.current.startOfDay(for: Date())
        let progress = min(1.0, task.completionContribution(for: today, period: period))
        let tintColor: Color = progress >= 1.0 ? .green : .blue
        let percentage = Int(progress * 100)

        return HStack(spacing: 4) {
            ProgressView(value: progress)
                .progressViewStyle(CircularProgressViewStyle(tint: tintColor))
                .frame(width: 18, height: 18)
            
            Text("\(period.displayName) \(percentage)%")
                .font(.caption2)
                .foregroundColor(progress >= 1.0 ? .green : .secondary)
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
    let onSave: (Set<Period>, TaskCategory, TaskWeight) -> Void
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedPeriods: Set<Period> = [.morning, .evening]
    @State private var selectedCategory: TaskCategory = .general
    @State private var selectedWeight: TaskWeight = .low
    
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
                            onSave(selectedPeriods, selectedCategory, selectedWeight)
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
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Category")
                        .font(.headline)
                    
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(TaskCategory.allCases) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .buttonStyle(BorderlessButtonStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Weight (effort required)")
                        .font(.headline)
                    
                    Picker("Weight", selection: $selectedWeight) {
                        ForEach(TaskWeight.allCases) { weight in
                            Text(weight.displayName).tag(weight)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
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
                        onSave(selectedPeriods, selectedCategory, selectedWeight)
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
    let task: Task
    let onSave: (Set<Period>, TaskCategory, TaskWeight) -> Void
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedPeriods: Set<Period>
    @State private var selectedCategory: TaskCategory
    @State private var selectedWeight: TaskWeight

    init(
        taskTitle: Binding<String>,
        originalTitle: String,
        task: Task,
        onSave: @escaping (Set<Period>, TaskCategory, TaskWeight) -> Void
    ) {
        self._taskTitle = taskTitle
        self.originalTitle = originalTitle
        self.task = task
        self.onSave = onSave
        self._selectedPeriods = State(initialValue: task.selectedPeriods)
        self._selectedCategory = State(initialValue: task.categoryEnum)
        self._selectedWeight = State(initialValue: task.weightEnum)
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Edit Habit")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Update your habit name and schedule")
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
                            saveTask()
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
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Category")
                        .font(.headline)
                    
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(TaskCategory.allCases) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Weight")
                        .font(.headline)
                    
                    Picker("Weight", selection: $selectedWeight) {
                        ForEach(TaskWeight.allCases) { weight in
                            Text(weight.displayName).tag(weight)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
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
                        saveTask()
                    }
                    .disabled(taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedPeriods.isEmpty)
                }
            }
        }
    }

    private func saveTask() {
        onSave(selectedPeriods, selectedCategory, selectedWeight)
    }
}

// MARK: - OneOffTodos View

struct OneOffTodosView: View {
    @EnvironmentObject private var viewModel: TaskViewModel
    @State private var showingAddTodo = false
    @State private var newTodoTitle = ""
    @State private var editingTodo: OneOffTodo?
    
    var pendingTodos: [OneOffTodo] {
        viewModel.oneOffTodos
            .filter { $0.statusEnum == .pending }
            .sorted { todo1, todo2 in
                // First, sort by due date presence (with due date comes first)
                let todo1HasDueDate = todo1.dueDate != nil
                let todo2HasDueDate = todo2.dueDate != nil

                if todo1HasDueDate && !todo2HasDueDate {
                    return true // todo1 comes first
                } else if !todo1HasDueDate && todo2HasDueDate {
                    return false // todo2 comes first
                } else if todo1HasDueDate && todo2HasDueDate {
                    // Both have due dates, sort by earliest date/time
                    return todo1.dueDate! < todo2.dueDate!
                } else {
                    // Neither has due date, sort by creation date
                    return (todo1.created ?? Date.distantPast) < (todo2.created ?? Date.distantPast)
                }
            }
    }

    var completedTodos: [OneOffTodo] {
        viewModel.oneOffTodos
            .filter { $0.statusEnum == .completed }
            .sorted { todo1, todo2 in
                return (todo1.created ?? Date.distantPast) > (todo2.created ?? Date.distantPast)
            }
    }

    var failedTodos: [OneOffTodo] {
        viewModel.oneOffTodos
            .filter { $0.statusEnum == .failed }
            .sorted { todo1, todo2 in
                return (todo1.created ?? Date.distantPast) > (todo2.created ?? Date.distantPast)
            }
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
                                    .contextMenu {
                                        Button("Edit Due Date/Time") {
                                            editingTodo = todo
                                        }
                                    }
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
            AddOneOffTodoView(newTodoTitle: $newTodoTitle) { dueDate in
                if !newTodoTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    viewModel.addOneOffTodo(title: newTodoTitle, dueDate: dueDate)
                    newTodoTitle = ""
                }
                showingAddTodo = false
            }
        }
        .sheet(item: $editingTodo, onDismiss: { editingTodo = nil }) { todo in
            EditOneOffTodoView(todo: todo) { newDate in
                viewModel.updateOneOffTodoDueDate(todo, to: newDate)
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

                HStack(spacing: 6) {
                    Text("Added \(todo.created ?? Date(), style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let dueDate = todo.dueDate {
                        Spacer()
                        Text("Due \(dueDate, formatter: DateFormatter.todoDueFormatter)")
                            .font(.caption)
                            .foregroundColor(todo.isOverdue ? .red : .secondary)
                            .fontWeight(todo.isOverdue ? .semibold : .regular)
                    }
                }
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
    let onSave: (Date?) -> Void
    @Environment(\.presentationMode) var presentationMode
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var hasDueTime = false
    @State private var dueTime = Date()

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add Quick Note")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Add a todo with optional due date and time")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.top)

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Note")
                            .font(.headline)

                        TextField("e.g., Call dentist, Buy groceries", text: $newTodoTitle)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .submitLabel(.done)
                    }

                    Toggle("Set due date", isOn: $hasDueDate)

                    if hasDueDate {
                        DatePicker("Due Date", selection: $dueDate, in: Date()..., displayedComponents: .date)
                            .datePickerStyle(CompactDatePickerStyle())

                        Toggle("Set time", isOn: $hasDueTime)

                        if hasDueTime {
                            DatePicker("Time", selection: $dueTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(CompactDatePickerStyle())
                        }
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
                        let finalDueDate: Date? = {
                            guard hasDueDate else { return nil }
                            if hasDueTime {
                                // Combine selected date and time
                                let calendar = Calendar.current
                                let dateComponents = calendar.dateComponents([.year, .month, .day], from: dueDate)
                                let timeComponents = calendar.dateComponents([.hour, .minute], from: dueTime)
                                var combined = DateComponents()
                                combined.year = dateComponents.year
                                combined.month = dateComponents.month
                                combined.day = dateComponents.day
                                combined.hour = timeComponents.hour
                                combined.minute = timeComponents.minute
                                return calendar.date(from: combined)
                            } else {
                                // Store start of day for date-only; scheduler will default to 9 AM
                                return Calendar.current.startOfDay(for: dueDate)
                            }
                        }()
                        onSave(finalDueDate)
                    }
                    .disabled(newTodoTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Edit OneOffTodo View

struct EditOneOffTodoView: View {
    let todo: OneOffTodo
    let onSave: (Date?) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Date()
    @State private var hasDueTime: Bool = false
    @State private var dueTime: Date = Date()
    
    init(todo: OneOffTodo, onSave: @escaping (Date?) -> Void) {
        self.todo = todo
        self.onSave = onSave
        // Initialize state from existing dueDate
        if let existing = todo.dueDate {
            let calendar = Calendar.current
            _hasDueDate = State(initialValue: true)
            _dueDate = State(initialValue: calendar.startOfDay(for: existing))
            let comps = calendar.dateComponents([.hour, .minute, .second], from: existing)
            let hasTime = (comps.hour ?? 0) != 0 || (comps.minute ?? 0) != 0 || (comps.second ?? 0) != 0
            _hasDueTime = State(initialValue: hasTime)
            _dueTime = State(initialValue: existing)
        } else {
            _hasDueDate = State(initialValue: false)
            _dueDate = State(initialValue: Date())
            _hasDueTime = State(initialValue: false)
            _dueTime = State(initialValue: Date())
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Edit Due Date/Time")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                Toggle("Set due date", isOn: $hasDueDate)
                
                if hasDueDate {
                    DatePicker("Due Date", selection: $dueDate, in: Date()..., displayedComponents: .date)
                        .datePickerStyle(CompactDatePickerStyle())
                    
                    Toggle("Set time", isOn: $hasDueTime)
                    
                    if hasDueTime {
                        DatePicker("Time", selection: $dueTime, displayedComponents: .hourAndMinute)
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
                    Button("Save") {
                        let finalDueDate: Date? = {
                            guard hasDueDate else { return nil }
                            if hasDueTime {
                                let calendar = Calendar.current
                                let dateComponents = calendar.dateComponents([.year, .month, .day], from: dueDate)
                                let timeComponents = calendar.dateComponents([.hour, .minute], from: dueTime)
                                var combined = DateComponents()
                                combined.year = dateComponents.year
                                combined.month = dateComponents.month
                                combined.day = dateComponents.day
                                combined.hour = timeComponents.hour
                                combined.minute = timeComponents.minute
                                return calendar.date(from: combined)
                            } else {
                                // Store start of day; scheduler will default to 9 AM
                                return Calendar.current.startOfDay(for: dueDate)
                            }
                        }()
                        onSave(finalDueDate)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

extension DateFormatter {
    static let todoDueFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short // shows time if present
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
