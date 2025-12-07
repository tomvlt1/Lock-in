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
    @Published private(set) var plankEntries: [PlankEntry] = []
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
        loadPlankEntries()
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

    func loadPlankEntries() {
        let request: NSFetchRequest<PlankEntry> = PlankEntry.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \PlankEntry.date, ascending: false)]

        do {
            plankEntries = try context.fetch(request)
        } catch {
            print("Failed to load plank entries: \(error)")
            plankEntries = []
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
        loadPlankEntries()
    }
    
    // MARK: - Task Management
    
    func addTask(
        title: String,
        periods: Set<Period>,
        category: TaskCategory = .general,
        weight: TaskWeight = .low
    ) {
        _ = Task(
            context: context,
            title: title,
            periods: periods,
            category: category,
            weight: weight
        )
        saveContext()
    }
    
    func updateTask(
        _ task: Task,
        title: String,
        periods: Set<Period>,
        category: TaskCategory,
        weight: TaskWeight
    ) {
        task.title = title
        task.selectedPeriods = periods
        task.categoryEnum = category
        task.weightEnum = weight
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
        let units = completed ? task.weightEnum.requiredUnits : 0
        setTaskProgress(task, for: date, period: period, progressUnits: units)
    }
    
    func currentProgress(for task: Task, date: Date, period: Period) -> Int {
        let day = Calendar.current.startOfDay(for: date)
        return task.completion(for: day, period: period)?.progressUnitsValue ?? 0
    }
    
    func setTaskProgress(_ task: Task, for date: Date, period: Period, progressUnits: Int) {
        applyProgress(task, for: date, period: period, progressUnits: progressUnits)
        saveContext()
    }
    
    func bulkSetTaskProgress(
        for date: Date,
        period: Period,
        updates: [(task: Task, progressUnits: Int)]
    ) {
        guard !updates.isEmpty else { return }
        for entry in updates {
            applyProgress(entry.task, for: date, period: period, progressUnits: entry.progressUnits)
        }
        saveContext()
    }
    
    private func applyProgress(_ task: Task, for date: Date, period: Period, progressUnits: Int) {
        let day = Calendar.current.startOfDay(for: date)
        let clamped = max(0, min(task.weightEnum.requiredUnits, progressUnits))
        
        if let existing = task.completion(for: day, period: period) {
            if clamped == 0 {
                context.delete(existing)
            } else {
                existing.progressUnitsValue = clamped
            }
        } else {
            if clamped > 0 {
                let comp = Completion(context: context, date: day, period: period, progressUnits: clamped)
                comp.task = task
            }
        }
    }
    
    // Overwrite all tasks’ completion for a specific date/period based on a set of completed IDs
    func logMissedTasks(for date: Date, period: Period, completedTaskIds: Set<UUID>) {
        let day = Calendar.current.startOfDay(for: date)
        let tasksForPeriod = activeTasks.filter { $0.isApplicable(for: period) }
        
        for task in tasksForPeriod {
            let isCompleted = (task.id != nil) && completedTaskIds.contains(task.id!)
            applyProgress(
                task,
                for: day,
                period: period,
                progressUnits: isCompleted ? task.weightEnum.requiredUnits : 0
            )
        }
        
        saveContext()
    }
    
    // MARK: - One-Off Todos
    
    func addOneOffTodo(title: String, dueDate: Date?) {
        let todo = OneOffTodo(context: context, title: title, dueDate: dueDate)
        if let id = todo.id, let due = dueDate {
            NotificationManager.shared.scheduleOneOffReminder(id: id, title: title, date: due)
        }
        syncCalendarEventIfNeeded(for: todo)
        saveContext()
    }
    
    func updateOneOffTodoDueDate(_ todo: OneOffTodo, to date: Date?) {
        let previousDueDate = todo.dueDate
        todo.dueDate = date
        if let id = todo.id {
            NotificationManager.shared.cancelOneOffReminder(id: id)
            if let date = date {
                NotificationManager.shared.scheduleOneOffReminder(id: id, title: todo.title ?? "Reminder", date: date)
            }
        }

        if let previousDueDate = previousDueDate, previousDueDate != date {
            removeCalendarEventIfPossible(for: todo, dueDateOverride: previousDueDate)
        }

        if date == nil {
            removeCalendarEventIfPossible(for: todo)
        } else {
            syncCalendarEventIfNeeded(for: todo)
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
        syncCalendarEventIfNeeded(for: todo)
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
        syncCalendarEventIfNeeded(for: todo)
        saveContext()
    }
    
    func deleteOneOffTodo(_ todo: OneOffTodo) {
        if let id = todo.id {
            NotificationManager.shared.cancelOneOffReminder(id: id)
        }
        removeCalendarEventIfPossible(for: todo)
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
                guard let date = entry.date else { return nil }
                return (date: date, weight: entry.weight)
            }
            .sorted { $0.date > $1.date } // Most recent first
    }

    // MARK: - Plank Tracking

    func addPlankEntry(durationSeconds: Double, date: Date = Date()) {
        let calendar = Calendar.current
        if let existing = plankEntries.first(where: { entry in
            guard let entryDate = entry.date else { return false }
            return calendar.isDate(entryDate, inSameDayAs: date)
        }) {
            existing.durationSeconds = durationSeconds
            existing.date = date
        } else {
            _ = PlankEntry(context: context, durationSeconds: durationSeconds, date: date)
        }
        saveContext()
    }

    func deletePlankEntry(_ entry: PlankEntry) {
        context.delete(entry)
        saveContext()
    }

    func getDailyPlankTotals(forLast days: Int = 14) -> [(date: Date, seconds: Double)] {
        let calendar = Calendar.current
        var totals: [Date: Double] = [:]

        for entry in plankEntries {
            guard let date = entry.date else { continue }
            let day = calendar.startOfDay(for: date)
            totals[day, default: 0] += entry.durationSeconds
        }

        var result: [(Date, Double)] = []
        for offset in stride(from: days - 1, through: 0, by: -1) {
            if let date = calendar.date(byAdding: .day, value: -offset, to: Date()) {
                let day = calendar.startOfDay(for: date)
                let value = totals[day] ?? 0
                result.append((day, value))
            }
        }
        return result
    }
    
    // MARK: - Analytics
    
    private func calculateDailyCompletionRate(for date: Date) -> Double {
        let day = Calendar.current.startOfDay(for: date)
        var totalOpportunities = 0.0
        var completedUnits = 0.0
        
        for task in activeTasks {
            for period in Period.allCases where task.isApplicable(for: period) {
                totalOpportunities += 1
                completedUnits += task.completionContribution(for: day, period: period)
            }
        }
        return totalOpportunities > 0 ? completedUnits / totalOpportunities : 0.0
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
    
    func getMostSkippedTasks() -> [(task: Task, skippedDays: Int)] {
        return activeTasks
            .map { task in
                (task: task, skippedDays: consecutiveSkipDays(for: task))
            }
            .filter { $0.skippedDays > 0 }
            .sorted { $0.skippedDays > $1.skippedDays }
    }
    
    private func consecutiveSkipDays(for task: Task) -> Int {
        let calendar = Calendar.current
        var streak = 0
        var currentDay = calendar.startOfDay(for: Date())
        let creationDay = calendar.startOfDay(for: task.created ?? Date())
        
        while streak < 60 { // Prevent endless loops
            if calendar.compare(currentDay, to: creationDay, toGranularity: .day) == .orderedAscending {
                break
            }
            
            if isTaskFullyCompleted(task, on: currentDay) {
                break
            } else {
                streak += 1
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDay) else {
                    break
                }
                currentDay = previousDay
            }
        }
        
        return streak
    }
    
    private func isTaskFullyCompleted(_ task: Task, on date: Date) -> Bool {
        task.isFullyCompleted(on: date)
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

        if enabled {
            syncAllTodosToCalendar()
        } else {
            removeAllTodoCalendarEvents()
        }
    }

    // MARK: - Calendar Sync Helpers

    private func syncCalendarEventIfNeeded(for todo: OneOffTodo) {
        guard isCalendarSyncEnabled,
              calendarAccessGranted(),
              let dueDate = todo.dueDate,
              let id = todo.id else {
            return
        }

        CalendarManager.shared.addOrUpdateTodo(
            id: id,
            title: sanitizedTitle(for: todo),
            dueDate: dueDate,
            isCompleted: todo.statusEnum == .completed
        )
    }

    private func removeCalendarEventIfPossible(for todo: OneOffTodo, dueDateOverride: Date? = nil) {
        guard calendarAccessGranted(),
              let id = todo.id,
              let dueDate = dueDateOverride ?? todo.dueDate else {
            return
        }

        CalendarManager.shared.removeTodo(id: id, dueDate: dueDate)
    }

    private func sanitizedTitle(for todo: OneOffTodo) -> String {
        let trimmed = (todo.title ?? "Untitled Todo").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Todo" : trimmed
    }

    private func syncAllTodosToCalendar() {
        guard isCalendarSyncEnabled, calendarAccessGranted() else { return }
        loadOneOffTodos()
        for todo in oneOffTodos where todo.dueDate != nil {
            syncCalendarEventIfNeeded(for: todo)
        }
    }

    private func removeAllTodoCalendarEvents() {
        guard calendarAccessGranted() else { return }
        loadOneOffTodos()
        for todo in oneOffTodos {
            removeCalendarEventIfPossible(for: todo)
        }
    }

    private func calendarAccessGranted() -> Bool {
        CalendarManager.shared.authorizationStatus == .authorized
    }
    
    // MARK: - CSV Export (existing)
    func exportTaskHistoryToCSV() -> String {
        print("📊 === CSV EXPORT DEBUG START ===")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let calendar = Calendar.current

        // Fetch ALL tasks directly from Core Data (not from cached array)
        let tasksFetchRequest: NSFetchRequest<Task> = Task.fetchRequest()
        tasksFetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Task.title, ascending: true)]
        
        let allTasks: [Task]
        do {
            allTasks = try context.fetch(tasksFetchRequest)
            print("✅ Fetched \(allTasks.count) tasks from Core Data")
            for task in allTasks {
                print("  - Task: '\(task.title ?? "Untitled")' | Archived: \(task.archived) | Periods: \(task.selectedPeriods)")
            }
        } catch {
            print("❌ Error fetching tasks for CSV export: \(error)")
            return ""
        }
        
        // If no tasks at all, return empty string to trigger "no data" message
        guard !allTasks.isEmpty else {
            print("⚠️ No tasks found - returning empty string")
            return ""
        }
        
        var allDates = Set<Date>()

        // Collect all dates from task completions - fetch directly from Core Data
        let completionsFetchRequest: NSFetchRequest<Completion> = Completion.fetchRequest()
        do {
            let allCompletions = try context.fetch(completionsFetchRequest)
            print("✅ Fetched \(allCompletions.count) completions from Core Data")
            
            var completionsByTask: [String: Int] = [:]
            for completion in allCompletions {
                if let date = completion.date {
                    let dayDate = calendar.startOfDay(for: date)
                    allDates.insert(dayDate)
                }
                
                let taskName = completion.task?.title ?? "Unknown"
                completionsByTask[taskName, default: 0] += 1
            }
            
            print("  Completions by task:")
            for (taskName, count) in completionsByTask.sorted(by: { $0.key < $1.key }) {
                print("    - \(taskName): \(count) completions")
            }
        } catch {
            print("❌ Error fetching completions for CSV export: \(error)")
        }

        // Add dates from weight entries
        print("📏 Weight entries: \(weightEntries.count)")
        for weightEntry in weightEntries {
            if let date = weightEntry.date {
                let dayDate = calendar.startOfDay(for: date)
                allDates.insert(dayDate)
            }
        }

        // Also include last 90 days to show empty days too
        for i in 0..<90 {
            if let date = calendar.date(byAdding: .day, value: -i, to: Date()) {
                allDates.insert(calendar.startOfDay(for: date))
            }
        }

        let sortedDates = allDates.sorted()
        print("📅 Total unique dates: \(sortedDates.count)")
        if let firstDate = sortedDates.first, let lastDate = sortedDates.last {
            print("   Date range: \(dateFormatter.string(from: firstDate)) to \(dateFormatter.string(from: lastDate))")
        }

        // Build header row
        var headerColumns = ["Date"]
        for task in allTasks {
            for period in Period.allCases {
                if task.isApplicable(for: period) {
                    let taskTitle = (task.title ?? "Untitled").replacingOccurrences(of: ",", with: ";")
                    headerColumns.append("\(taskTitle)_\(period.displayName)")
                }
            }
        }
        headerColumns.append("Overall_Completion_%")
        headerColumns.append("Weight")
        
        print("📋 Header columns (\(headerColumns.count)): \(headerColumns.joined(separator: ", "))")

        var csvContent = headerColumns.joined(separator: ",") + "\n"

        // Build data rows
        for date in sortedDates {
            var rowData = [DateFormatter.csvDateFormatter.string(from: date)]

            for task in allTasks {
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
        
        print("✅ Generated CSV with \(csvContent.count) characters")
        print("📄 First 300 characters:")
        print(String(csvContent.prefix(300)))
        print("📊 === CSV EXPORT DEBUG END ===\n")

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

    // MARK: - CSV Import (tolerant + security scope fallback)

    enum CSVImportError: Error {
        case invalidFile
        case unreadableData
        case malformedHeader
        case malformedRow
        case dateParseFailed(String)
    }

    // Detect delimiter from header: prefer tab if present, else comma.
    private func detectDelimiter(in header: String) -> Character {
        if header.contains("\t") { return "\t" }
        return ","
    }

    // Split a row using the detected delimiter and trim whitespace around each cell.
    private func splitRow(_ row: String, delimiter: Character) -> [String] {
        // Simple split (no quoted-field handling), then trim spaces/tabs
        return row.split(separator: delimiter, omittingEmptySubsequences: false).map {
            String($0).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    // Parse date using multiple formats
    private func parseDate(_ s: String) -> Date? {
        let fmts = ["yyyy-MM-dd", "M/d/yy", "M/d/yyyy"]
        let posix = Locale(identifier: "en_US_POSIX")
        for fmt in fmts {
            let df = DateFormatter()
            df.locale = posix
            df.timeZone = TimeZone(secondsFromGMT: 0)
            df.dateFormat = fmt
            if let d = df.date(from: s) {
                // Normalize to start of day for consistency
                return Calendar.current.startOfDay(for: d)
            }
        }
        return nil
    }

    // Import your own exported CSV format, but tolerate tab-delimited files,
    // flexible dates, and headers with spaces around underscores.
    // Returns a short summary string.
    func importFromCSV(url: URL) throws -> String {
        // Try to start security-scoped access; if it fails, continue anyway.
        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw CSVImportError.unreadableData
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw CSVImportError.unreadableData
        }

        // Split into lines
        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        guard lines.count > 1 else {
            throw CSVImportError.malformedHeader
        }

        // Detect delimiter from header line
        let headerLine = lines[0]
        let delimiter = detectDelimiter(in: headerLine)

        // Parse header cells
        let header = splitRow(headerLine, delimiter: delimiter)
        guard header.count >= 2 else {
            throw CSVImportError.malformedHeader
        }
        guard header[0].caseInsensitiveCompare("Date") == .orderedSame else {
            throw CSVImportError.malformedHeader
        }

        // Find indices of special columns (last occurrence)
        let weightIndex = header.lastIndex(where: { $0 == "Weight" })
        let overallIndex = header.lastIndex(where: { $0 == "Overall_Completion_%" })

        let endTaskColumnsIndex = min(
            overallIndex ?? header.count,
            weightIndex ?? header.count
        )

        // Parse task columns: normalize "Title _Morning" -> ("Title", .morning)
        var taskPeriods: [String: Set<Period>] = [:]
        var taskColumnDescriptors: [(title: String, period: Period, index: Int)] = []

        if endTaskColumnsIndex > 1 {
            for idx in 1..<endTaskColumnsIndex {
                let col = header[idx]
                // Split on first underscore
                if let underscore = col.firstIndex(of: "_") {
                    let rawTitle = String(col[..<underscore])
                    let rawSuffix = String(col[col.index(after: underscore)...])
                    let titlePart = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: ";", with: ",") // reverse export escaping
                    let suffix = rawSuffix.trimmingCharacters(in: .whitespacesAndNewlines)
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

        // Ensure tasks exist / update periods
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

        let calendar = Calendar.current

        var importedCompletions = 0
        var importedWeights = 0
        var processedDates = 0

        // Process data rows
        for i in 1..<lines.count {
            let row = splitRow(lines[i], delimiter: delimiter)
            if row.isEmpty { continue }

            let dateString = row[0]
            guard let date = parseDate(dateString) else {
                throw CSVImportError.dateParseFailed(dateString)
            }
            let dayDate = calendar.startOfDay(for: date)

            // Completions
            for desc in taskColumnDescriptors {
                guard desc.index < row.count else { continue }
                let value = row[desc.index].trimmingCharacters(in: .whitespacesAndNewlines)
                guard value == "1" else { continue }
                if let task = titleToTask[desc.title], !task.isCompleted(for: dayDate, period: desc.period) {
                    let completion = Completion(
                        context: context,
                        date: dayDate,
                        period: desc.period,
                        progressUnits: task.weightEnum.requiredUnits
                    )
                    completion.task = task
                    importedCompletions += 1
                }
            }

            // Weight
            if let weightIdx = weightIndex, weightIdx < row.count {
                let w = row[weightIdx].trimmingCharacters(in: .whitespacesAndNewlines)
                if !w.isEmpty, let weight = Double(w) {
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
}

// MARK: - DateFormatter helpers

extension DateFormatter {
    static let csvDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        return df;
    }()
}
