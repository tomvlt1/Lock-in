import CoreData
import SwiftUI
import Foundation
import EventKit

@MainActor
class TaskViewModel: ObservableObject {
    var persistenceController: PersistenceController
    var context: NSManagedObjectContext
    
    @Published private(set) var tasks: [Task] = []
    @Published private(set) var oneOffTodos: [OneOffTodo] = []
    @Published private(set) var weightEntries: [WeightEntry] = []
    @Published private(set) var settings: AppSettings?

    private var isCalendarSyncEnabled: Bool {
        settings?.calendarSyncEnabled ?? false
    }
    
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
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WeightEntry.date, ascending: true)]
        
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
                if existingSettings.value(forKey: "calendarSyncEnabled") == nil {
                    existingSettings.calendarSyncEnabled = false
                    saveContext()
                }
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
    
    // MARK: - Core Data Save
    
    private func saveContext() {
        persistenceController.save()
        // Refresh published arrays to reflect changes
        loadTasks()
        loadOneOffTodos()
        loadWeightEntries()
    }
    
    // MARK: - Task Management
    
    func addTask(title: String, periods: Set<Period>) {
        let task = Task(context: context, title: title, periods: periods)
        task.archived = false
        saveContext()
    }
    
    func updateTask(_ task: Task, title: String) {
        task.title = title
        saveContext()
    }
    
    func deleteTask(_ task: Task) {
        context.delete(task)
        saveContext()
    }
    
    func archiveTask(_ task: Task) {
        task.archived = true
        saveContext()
    }
    
    func unarchiveTask(_ task: Task) {
        task.archived = false
        saveContext()
    }
    
    // Return tasks for today for a period, along with completion status for today.
    func getTasksForToday(period: Period) -> [(task: Task, completed: Bool)] {
        let today = Calendar.current.startOfDay(for: Date())
        return activeTasks
            .filter { $0.isApplicable(for: period) }
            .map { task in
                let isCompleted = task.isCompleted(for: today, period: period)
                return (task: task, completed: isCompleted)
            }
    }
    
    // Toggle/mark completion for a specific date/period
    func markTaskCompletion(_ task: Task, for date: Date, period: Period, completed: Bool) {
        let day = Calendar.current.startOfDay(for: date)
        
        if let existing = task.completion(for: day, period: period) {
            existing.skipped = !completed
        } else {
            let comp = Completion(context: context, date: day, period: period, skipped: !completed)
            comp.task = task
        }
        
        saveContext()
    }
    
    // Overwrite all tasks’ completion for a specific date/period based on a set of completed IDs
    func logMissedTasks(for date: Date, period: Period, completedTaskIds: Set<UUID>) {
        let day = Calendar.current.startOfDay(for: date)
        let tasksForPeriod = activeTasks.filter { $0.isApplicable(for: period) }
        
        for task in tasksForPeriod {
            let isCompleted = (task.id != nil) && completedTaskIds.contains(task.id!)
            if let existing = task.completion(for: day, period: period) {
                existing.skipped = !isCompleted
            } else {
                let comp = Completion(context: context, date: day, period: period, skipped: !isCompleted)
                comp.task = task
            }
        }
        
        saveContext()
    }
    
    // MARK: - One-Off Todos
    
    func addOneOffTodo(title: String, dueDate: Date?) {
        let todo = OneOffTodo(context: context, title: title, dueDate: dueDate)
        if let id = todo.id, let due = dueDate {
            NotificationManager.shared.scheduleOneOffReminder(id: id, title: title, date: due)
        }
        saveContext()
    }
    
    func updateOneOffTodoDueDate(_ todo: OneOffTodo, to date: Date?) {
        todo.dueDate = date
        if let id = todo.id {
            NotificationManager.shared.cancelOneOffReminder(id: id)
            if let date = date {
                NotificationManager.shared.scheduleOneOffReminder(id: id, title: todo.title ?? "Reminder", date: date)
            }
        }
        saveContext()
    }
    
    func toggleOneOffTodo(_ todo: OneOffTodo) {
        switch todo.statusEnum {
        case .pending:
            todo.statusEnum = .completed
        case .completed:
            todo.statusEnum = .pending
        case .failed:
            todo.statusEnum = .pending
        }
        if let id = todo.id {
            if todo.statusEnum != .pending {
                NotificationManager.shared.cancelOneOffReminder(id: id)
            }
        }
        saveContext()
    }
    
    func setOneOffTodoStatus(_ todo: OneOffTodo, status: TodoStatus) {
        todo.statusEnum = status
        if let id = todo.id {
            if status != .pending {
                NotificationManager.shared.cancelOneOffReminder(id: id)
            } else if let due = todo.dueDate {
                NotificationManager.shared.scheduleOneOffReminder(id: id, title: todo.title ?? "Reminder", date: due)
            }
        }
        saveContext()
    }
    
    func deleteOneOffTodo(_ todo: OneOffTodo) {
        if let id = todo.id {
            NotificationManager.shared.cancelOneOffReminder(id: id)
        }
        context.delete(todo)
        saveContext()
    }
    
    // MARK: - Weight Tracking
    
    func addWeightEntry(weight: Double, date: Date) {
        _ = WeightEntry(context: context, weight: weight, date: date)
        saveContext()
    }
    
    func deleteWeightEntry(_ entry: WeightEntry) {
        context.delete(entry)
        saveContext()
    }
    
    func getWeightEntriesForChart() -> [(date: Date, weight: Double)] {
        weightEntries
            .compactMap { entry in
                guard let d = entry.date else { return nil }
                return (date: d, weight: entry.weight)
            }
            .sorted { $0.date < $1.date }
    }
    
    // MARK: - Analytics
    
    private func calculateDailyCompletionRate(for date: Date) -> Double {
        let day = Calendar.current.startOfDay(for: date)
        var total = 0
        var done = 0
        
        for task in activeTasks {
            for period in Period.allCases where task.isApplicable(for: period) {
                total += 1
                if task.isCompleted(for: day, period: period) {
                    done += 1
                }
            }
        }
        return total > 0 ? Double(done) / Double(total) : 0.0
    }
    
    func getCompletionRatesForLast30Days() -> [(date: Date, rate: Double)] {
        let calendar = Calendar.current
        var result: [(Date, Double)] = []
        for i in stride(from: 29, through: 0, by: -1) {
            if let date = calendar.date(byAdding: .day, value: -i, to: Date()) {
                let day = calendar.startOfDay(for: date)
                let rate = calculateDailyCompletionRate(for: day)
                result.append((day, rate))
            }
        }
        return result
    }
    
    func getMostSkippedTasks() -> [(task: Task, skipRate: Double)] {
        return activeTasks
            .map { ($0, $0.skipRate) }
            .sorted { $0.1 > $1.1 }
    }
    
    // MARK: - Settings / Notifications / Calendar
    
    func toggleNotifications(_ enabled: Bool) {
        guard let settings = settings else { return }
        settings.notificationsEnabled = enabled
        
        if enabled {
            let morning = settings.morningReminderTime ?? Period.morning.defaultTime
            let evening = settings.eveningReminderTime ?? Period.evening.defaultTime
            NotificationManager.shared.scheduleHabitReminders(morningTime: morning, eveningTime: evening)
        } else {
            NotificationManager.shared.cancelHabitReminders()
        }
        saveContext()
    }
    
    func updateNotificationTimes(morning: Date, evening: Date) {
        guard let settings = settings else { return }
        settings.morningReminderTime = morning
        settings.eveningReminderTime = evening
        if settings.notificationsEnabled {
            NotificationManager.shared.scheduleHabitReminders(morningTime: morning, eveningTime: evening)
        }
        saveContext()
    }
    
    func updateCalendarSyncPreference(_ enabled: Bool) {
        guard let settings = settings else { return }
        settings.calendarSyncEnabled = enabled
        saveContext()
    }
    
    // MARK: - CSV Export (existing)
    func exportTaskHistoryToCSV() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let calendar = Calendar.current

        let allTasks = tasks
        var allDates = Set<Date>()

        for task in allTasks {
            let completions = task.completionsArray
            for completion in completions {
                if let date = completion.date {
                    let dayDate = calendar.startOfDay(for: date)
                    allDates.insert(dayDate)
                }
            }
        }

        for weightEntry in weightEntries {
            if let date = weightEntry.date {
                let dayDate = calendar.startOfDay(for: date)
                allDates.insert(dayDate)
            }
        }

        for i in 0..<30 {
            if let date = calendar.date(byAdding: .day, value: -i, to: Date()) {
                allDates.insert(calendar.startOfDay(for: date))
            }
        }

        let sortedDates = allDates.sorted()

        var headerColumns = ["Date"]
        for task in allTasks.sorted(by: { ($0.title ?? "") < ($1.title ?? "") }) {
            for period in Period.allCases {
                if task.isApplicable(for: period) {
                    let taskTitle = (task.title ?? "Untitled").replacingOccurrences(of: ",", with: ";")
                    headerColumns.append("\(taskTitle)_\(period.displayName)")
                }
            }
        }
        headerColumns.append("Overall_Completion_%")
        headerColumns.append("Weight")

        var csvContent = headerColumns.joined(separator: ",") + "\n"

        for date in sortedDates {
            var rowData = [DateFormatter.csvDateFormatter.string(from: date)]

            for task in allTasks.sorted(by: { ($0.title ?? "") < ($1.title ?? "") }) {
                for period in Period.allCases {
                    if task.isApplicable(for: period) {
                        let isCompleted = task.isCompleted(for: date, period: period)
                        rowData.append(isCompleted ? "1" : "0")
                    }
                }
            }

            let dailyRate = calculateDailyCompletionRate(for: date)
            rowData.append(String(format: "%.1f", dailyRate * 100))

            let weightForDate = getWeightForDate(date)
            let weightString = weightForDate > 0 ? String(format: "%.1f", weightForDate) : ""
            rowData.append(weightString)

            csvContent += rowData.joined(separator: ",") + "\n"
        }

        return csvContent
    }

    private func getWeightForDate(_ date: Date) -> Double {
        let calendar = Calendar.current

        for weightEntry in weightEntries {
            if let entryDate = weightEntry.date,
               calendar.isDate(entryDate, inSameDayAs: date) {
                return weightEntry.weight
            }
        }

        return 0.0
    }

    // MARK: - CSV Import (now synchronous)

    enum CSVImportError: Error {
        case invalidFile
        case unreadableData
        case malformedHeader
        case malformedRow
        case dateParseFailed(String)
    }

    // Import your own exported CSV format.
    // Returns a short summary string.
    func importFromCSV(url: URL) throws -> String {
        guard url.startAccessingSecurityScopedResource() else {
            throw CSVImportError.invalidFile
        }
        defer { url.stopAccessingSecurityScopedResource() }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw CSVImportError.unreadableData
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw CSVImportError.unreadableData
        }

        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        guard lines.count > 1 else {
            throw CSVImportError.malformedHeader
        }

        let header = splitCSVRow(lines[0])
        guard header.count >= 2 else {
            throw CSVImportError.malformedHeader
        }
        guard header[0].caseInsensitiveCompare("Date") == .orderedSame else {
            throw CSVImportError.malformedHeader
        }

        let weightIndex = header.lastIndex(where: { $0 == "Weight" })
        let overallIndex = header.lastIndex(where: { $0 == "Overall_Completion_%" })

        let endTaskColumnsIndex = min(
            overallIndex ?? header.count,
            weightIndex ?? header.count
        )

        var taskPeriods: [String: Set<Period>] = [:]
        var taskColumnDescriptors: [(title: String, period: Period, index: Int)] = []

        if endTaskColumnsIndex > 1 {
            for idx in 1..<endTaskColumnsIndex {
                let col = header[idx]
                if let underscore = col.lastIndex(of: "_") {
                    let titlePart = String(col[..<underscore]).replacingOccurrences(of: ";", with: ",")
                    let suffix = String(col[col.index(after: underscore)...])
                    let period: Period?
                    if suffix.caseInsensitiveCompare("Morning") == .orderedSame {
                        period = .morning
                    } else if suffix.caseInsensitiveCompare("Evening") == .orderedSame {
                        period = .evening
                    } else {
                        period = nil
                    }
                    if let period = period {
                        taskPeriods[titlePart, default: []].insert(period)
                        taskColumnDescriptors.append((title: titlePart, period: period, index: idx))
                    }
                }
            }
        }

        var titleToTask: [String: Task] = [:]
        for (title, periods) in taskPeriods {
            if let existing = tasks.first(where: { ($0.title ?? "") == title }) {
                existing.selectedPeriods = periods
                titleToTask[title] = existing
            } else {
                let newTask = Task(context: context, title: title, periods: periods)
                titleToTask[title] = newTask
            }
        }

        let dateFormatter = DateFormatter.csvDateFormatter
        let calendar = Calendar.current

        var importedCompletions = 0
        var importedWeights = 0
        var processedDates = 0

        for i in 1..<lines.count {
            let row = splitCSVRow(lines[i])
            if row.isEmpty { continue }
            let dateString = row[0]
            guard let date = dateFormatter.date(from: dateString) else {
                throw CSVImportError.dateParseFailed(dateString)
            }
            let dayDate = calendar.startOfDay(for: date)

            for desc in taskColumnDescriptors {
                guard desc.index < row.count else { continue }
                let value = row[desc.index].trimmingCharacters(in: .whitespacesAndNewlines)
                guard value == "1" else { continue }
                if let task = titleToTask[desc.title] {
                    if !task.isCompleted(for: dayDate, period: desc.period) {
                        let completion = Completion(context: context, date: dayDate, period: desc.period, skipped: false)
                        completion.task = task
                        importedCompletions += 1
                    }
                }
            }

            if let weightIdx = weightIndex, weightIdx < row.count {
                let w = row[weightIdx].trimmingCharacters(in: .whitespacesAndNewlines)
                if let weight = Double(w) {
                    if let existing = weightEntries.first(where: { entry in
                        guard let d = entry.date else { return false }
                        return calendar.isDate(d, inSameDayAs: dayDate)
                    }) {
                        existing.weight = weight
                        existing.date = dayDate
                    } else {
                        _ = WeightEntry(context: context, weight: weight, date: dayDate)
                    }
                    importedWeights += 1
                }
            }

            processedDates += 1
        }

        saveContext()
        loadTasks()
        loadWeightEntries()

        return "dates: \(processedDates), completions: \(importedCompletions), weights: \(importedWeights)"
    }

    private func splitCSVRow(_ row: String) -> [String] {
        row.split(separator: ",", omittingEmptySubsequences: false).map { String($0) }
    }
}

// MARK: - DateFormatter helpers

extension DateFormatter {
    static let csvDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        return df
    }()
}

