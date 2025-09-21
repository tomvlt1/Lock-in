import CoreData
import SwiftUI
import Foundation

@MainActor
class TaskViewModel: ObservableObject {
    var persistenceController: PersistenceController
    var context: NSManagedObjectContext
    
    @Published private(set) var tasks: [Task] = []
    @Published private(set) var oneOffTodos: [OneOffTodo] = []
    @Published private(set) var weightEntries: [WeightEntry] = []
    @Published private(set) var settings: AppSettings?
    
    var activeTasks: [Task] {
        tasks.filter { !$0.archived }
    }
    
    var archivedTasks: [Task] {
        tasks.filter { $0.archived }
    }
    
    init(persistenceController: PersistenceController = PersistenceController.shared) {
        self.persistenceController = persistenceController
        self.context = persistenceController.context
        loadTasks()
        loadOneOffTodos()
        loadWeightEntries()
        loadSettings()
    }
    
    // MARK: - Data Loading
    
    func loadTasks() {
        let request: NSFetchRequest<Task> = Task.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Task.created, ascending: true)]
        
        do {
            tasks = try context.fetch(request)
        } catch {
            print("Failed to load tasks: \(error)")
            tasks = []
        }
    }
    
    func loadOneOffTodos() {
        let request: NSFetchRequest<OneOffTodo> = OneOffTodo.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \OneOffTodo.created, ascending: true)]
        
        do {
            oneOffTodos = try context.fetch(request)
        } catch {
            print("Failed to load one-off todos: \(error)")
            oneOffTodos = []
        }
    }
    
    func loadWeightEntries() {
        let request: NSFetchRequest<WeightEntry> = WeightEntry.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WeightEntry.date, ascending: false)]
        
        do {
            weightEntries = try context.fetch(request)
        } catch {
            print("Failed to load weight entries: \(error)")
            weightEntries = []
        }
    }
    
    func loadSettings() {
        let request: NSFetchRequest<AppSettings> = AppSettings.fetchRequest()
        
        do {
            let fetchedSettings = try context.fetch(request)
            
            if let existingSettings = fetchedSettings.first {
                settings = existingSettings
            } else {
                // Create default settings
                settings = AppSettings.defaultSettings(context: context)
                saveContext()
            }
        } catch {
            print("Failed to load settings: \(error)")
            // Create default settings on error
            settings = AppSettings.defaultSettings(context: context)
            saveContext()
        }
    }
    
    // MARK: - Task Management
    
    func addTask(title: String, periods: Set<Period> = [.morning, .evening]) {
        _ = Task(context: context, title: title, periods: periods)
        saveContext()
        loadTasks()
    }
    
    func updateTask(_ task: Task, title: String) {
        task.title = title
        saveContext()
        loadTasks()
    }
    
    func archiveTask(_ task: Task) {
        task.archived = true
        saveContext()
        loadTasks()
    }
    
    func unarchiveTask(_ task: Task) {
        task.archived = false
        saveContext()
        loadTasks()
    }
    
    func deleteTask(_ task: Task) {
        context.delete(task)
        saveContext()
        loadTasks()
    }
    
    // MARK: - OneOffTodo Management
    
    func addOneOffTodo(title: String) {
        _ = OneOffTodo(context: context, title: title)
        saveContext()
        loadOneOffTodos()
    }
    
    func toggleOneOffTodo(_ todo: OneOffTodo) {
        switch todo.statusEnum {
        case .pending:
            todo.statusEnum = .completed
        case .completed, .failed:
            todo.statusEnum = .pending
        }
        saveContext()
        loadOneOffTodos()
    }
    
    func setOneOffTodoStatus(_ todo: OneOffTodo, status: TodoStatus) {
        todo.statusEnum = status
        saveContext()
        loadOneOffTodos()
    }
    
    func deleteOneOffTodo(_ todo: OneOffTodo) {
        context.delete(todo)
        saveContext()
        loadOneOffTodos()
    }
    
    // MARK: - Weight Entry Management
    
    func addWeightEntry(weight: Double, date: Date = Date()) {
        // Check if entry already exists for this date
        let calendar = Calendar.current
        if let existingEntry = weightEntries.first(where: { entry in
            guard let entryDate = entry.date else { return false }
            return calendar.isDate(entryDate, inSameDayAs: date)
        }) {
            // Update existing entry
            existingEntry.weight = weight
            existingEntry.date = date
        } else {
            // Create new entry
            _ = WeightEntry(context: context, weight: weight, date: date)
        }
        saveContext()
        loadWeightEntries()
    }
    
    func deleteWeightEntry(_ entry: WeightEntry) {
        context.delete(entry)
        saveContext()
        loadWeightEntries()
    }
    
    func getWeightEntriesForChart() -> [(date: Date, weight: Double)] {
        return weightEntries.compactMap { entry in
            guard let date = entry.date else { return nil }
            return (date: date, weight: entry.weight)
        }.sorted { $0.date < $1.date }
    }
    
    // MARK: - Completion Management
    
    func markTaskCompletion(_ task: Task, for date: Date, period: Period, completed: Bool) {
        // Remove existing completion if it exists
        if let existingCompletion = task.completion(for: date, period: period) {
            context.delete(existingCompletion)
        }
        
        // Add new completion
        let completion = Completion(context: context, date: date, period: period, skipped: !completed)
        completion.task = task
        
        saveContext()
        loadTasks()
    }
    
    func getTasksForToday(period: Period) -> [(task: Task, completed: Bool)] {
        let today = Date()
        return activeTasks
            .filter { $0.isApplicable(for: period) }
            .map { task in
                let completed = task.isCompleted(for: today, period: period)
                return (task: task, completed: completed)
            }
    }
    
    // MARK: - Analytics
    
    func calculateDailyCompletionRate(for date: Date) -> Double {
        let activeTasks = self.activeTasks
        guard !activeTasks.isEmpty else { return 0.0 }
        
        var totalOpportunities = 0
        var completedCount = 0
        
        for task in activeTasks {
            for period in Period.allCases {
                if task.isApplicable(for: period) {
                    totalOpportunities += 1
                    if task.isCompleted(for: date, period: period) {
                        completedCount += 1
                    }
                }
            }
        }
        
        return totalOpportunities > 0 ? Double(completedCount) / Double(totalOpportunities) : 0.0
    }
    
    func getCompletionRatesForLast30Days() -> [(date: Date, rate: Double)] {
        let calendar = Calendar.current
        let today = Date()
        var results: [(Date, Double)] = []
        
        for i in 0..<30 {
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            let rate = calculateDailyCompletionRate(for: date)
            results.append((date, rate))
        }
        
        return results.reversed() // Most recent first
    }
    
    func getSevenDayMovingAverage() -> [(date: Date, average: Double)] {
        let completionRates = getCompletionRatesForLast30Days()
        var results: [(Date, Double)] = []
        
        for i in 6..<completionRates.count {
            let endIndex = i + 1
            let startIndex = max(0, endIndex - 7)
            let slice = Array(completionRates[startIndex..<endIndex])
            let average = slice.map { $0.rate }.reduce(0, +) / Double(slice.count)
            results.append((completionRates[i].date, average))
        }
        
        return results
    }
    
    func getMostSkippedTasks() -> [(task: Task, skipRate: Double)] {
        return activeTasks
            .map { task in (task: task, skipRate: task.skipRate) }
            .filter { $0.skipRate > 0 }
            .sorted { $0.skipRate > $1.skipRate }
    }
    
    // MARK: - Settings Management
    
    func updateNotificationTimes(morning: Date, evening: Date) {
        guard let settings = settings else { return }
        
        settings.morningReminderTime = morning
        settings.eveningReminderTime = evening
        saveContext()
        
        // Update notifications
        NotificationManager.shared.scheduleHabitReminders(
            morningTime: morning,
            eveningTime: evening
        )
    }
    
    func toggleNotifications(_ enabled: Bool) {
        guard let settings = settings else { return }
        
        settings.notificationsEnabled = enabled
        saveContext()
        
        if enabled {
            // Use completion handler approach for iOS 14 compatibility
            NotificationManager.shared.requestPermission { granted in
                if granted {
                    NotificationManager.shared.scheduleHabitReminders(
                        morningTime: settings.morningReminderTime ?? Period.morning.defaultTime,
                        eveningTime: settings.eveningReminderTime ?? Period.evening.defaultTime
                    )
                }
            }
        } else {
            NotificationManager.shared.cancelHabitReminders()
        }
    }
    
    // MARK: - Persistence
    
    private func saveContext() {
        persistenceController.save()
    }
    
    // MARK: - Recovery Support
    
    func logMissedTasks(for date: Date, period: Period, completedTaskIds: Set<UUID>) {
        for task in activeTasks.filter({ $0.isApplicable(for: period) }) {
            let isCompleted = task.id != nil && completedTaskIds.contains(task.id!)
            markTaskCompletion(task, for: date, period: period, completed: isCompleted)
        }
    }
}

