import CoreData
import Foundation

struct SampleData {
    
    // MARK: - Sample Tasks
    
    static let sampleTasks = [
        "Drink 8 glasses of water",
        "Exercise for 30 minutes",
        "Read for 20 minutes",
        "Meditate for 10 minutes",
        "Take vitamins",
        "Write in journal",
        "Plan tomorrow's tasks",
        "Practice gratitude",
        "Stretch for 5 minutes",
        "Get 8 hours of sleep"
    ]
    
    // MARK: - Sample Data Generation
    
    @MainActor
    static func createSampleData(in context: NSManagedObjectContext) {
        // Clear existing data first
        clearAllData(in: context)
        
        // Create sample tasks
        let tasks = createSampleTasks(in: context)
        
        // Create sample completions for the past 30 days
        createSampleCompletions(for: tasks, in: context)
        
        // Create sample one-off todos
        createSampleOneOffTodos(in: context)
        
        // Create sample plank entries
        createSamplePlankEntries(in: context)
        
        // Create default settings
        createDefaultSettings(in: context)
        
        // Save context
        do {
            try context.save()
        } catch {
            print("Failed to save sample data: \(error)")
        }
    }
    
    private static func clearAllData(in context: NSManagedObjectContext) {
        // Delete all existing data
        let entityNames = ["Task", "Completion", "OneOffTodo", "AppSettings", "WeightEntry", "PlankEntry"]
        for entityName in entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            do {
                try context.execute(batchDeleteRequest)
            } catch {
                print("Failed to clear \(entityName): \(error)")
            }
        }
    }
    
    private static func createSampleTasks(in context: NSManagedObjectContext) -> [Task] {
        var tasks: [Task] = []
        
        let categories = TaskCategory.allCases
        let weights = TaskWeight.allCases
        
        for (index, taskTitle) in sampleTasks.enumerated() {
            let category = categories[index % categories.count]
            let weight = weights[index % weights.count]
            let task = Task(context: context, title: taskTitle, category: category, weight: weight)
            
            // Make some tasks older than others
            let daysAgo = Double.random(in: 5...30)
            task.created = Calendar.current.date(byAdding: .day, value: -Int(daysAgo), to: Date()) ?? Date()
            
            // Archive a couple of tasks for testing
            if index >= sampleTasks.count - 2 {
                task.archived = true
            }
            
            tasks.append(task)
        }
        
        return tasks
    }
    
    private static func createSampleCompletions(for tasks: [Task], in context: NSManagedObjectContext) {
        let calendar = Calendar.current
        let today = Date()
        
        // Generate completions for the past 30 days
        for dayOffset in 0..<30 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            
            for task in tasks {
                // Skip archived tasks for recent dates
                if task.archived && dayOffset < 7 { continue }
                
                for period in Period.allCases where task.isApplicable(for: period) {
                    // Create realistic completion patterns
                    let completionProbability = getCompletionProbability(
                        for: task,
                        dayOffset: dayOffset,
                        period: period
                    )
                    
                    let roll = Double.random(in: 0...1)
                    if roll < completionProbability {
                        let completion = Completion(
                            context: context,
                            date: date,
                            period: period,
                            progressUnits: task.weightEnum.requiredUnits
                        )
                        completion.task = task
                    } else if roll < completionProbability + 0.15 {
                        // Occasionally log partial progress to demonstrate slider states
                        let partialUnits = max(0, task.weightEnum.requiredUnits - 1)
                        if partialUnits > 0 {
                            let completion = Completion(
                                context: context,
                                date: date,
                                period: period,
                                progressUnits: partialUnits
                            )
                            completion.task = task
                        }
                    }
                }
            }
        }
    }
    
    private static func getCompletionProbability(for task: Task, dayOffset: Int, period: Period) -> Double {
        // Different tasks have different completion patterns
        let baseRate: Double
        
        switch task.title {
        case "Drink 8 glasses of water":
            baseRate = 0.85 // High consistency
        case "Exercise for 30 minutes":
            baseRate = period == .morning ? 0.65 : 0.45 // Better in morning
        case "Meditate for 10 minutes":
            baseRate = period == .morning ? 0.75 : 0.60
        case "Read for 20 minutes":
            baseRate = period == .evening ? 0.70 : 0.45 // Better in evening
        case "Write in journal":
            baseRate = period == .evening ? 0.80 : 0.30 // Much better in evening
        case "Take vitamins":
            baseRate = period == .morning ? 0.90 : 0.20 // Morning routine
        case "Plan tomorrow's tasks":
            baseRate = period == .evening ? 0.75 : 0.10 // Evening planning
        case "Practice gratitude":
            baseRate = 0.70
        case "Stretch for 5 minutes":
            baseRate = 0.60
        case "Get 8 hours of sleep":
            baseRate = period == .evening ? 0.65 : 0.85 // Better to track in morning
        default:
            baseRate = 0.60
        }
        
        // Reduce probability for older days (less consistent in the past)
        let ageMultiplier = max(0.4, 1.0 - Double(dayOffset) * 0.02)
        
        // Add some weekly variation (weekends might be different)
        let calendar = Calendar.current
        let today = Date()
        if let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
            let weekday = calendar.component(.weekday, from: date)
            let isWeekend = weekday == 1 || weekday == 7 // Sunday = 1, Saturday = 7
            let weekendMultiplier = isWeekend ? 0.8 : 1.0 // Slightly lower on weekends
            
            return baseRate * ageMultiplier * weekendMultiplier
        }
        
        return baseRate * ageMultiplier
    }
    
    private static func createSampleOneOffTodos(in context: NSManagedObjectContext) {
        let sampleTodos = [
            ("Call dentist", true),
            ("Buy groceries", false),
            ("Reply to Sarah's email", false),
            ("Schedule car maintenance", true),
            ("Research vacation destinations", false),
            ("Fix leaky faucet", false)
        ]
        
        for (title, completed) in sampleTodos {
            let todo = OneOffTodo(context: context, title: title)
            todo.completed = completed
            
            // Make some todos older than others
            let daysAgo = Double.random(in: 1...7)
            todo.created = Calendar.current.date(byAdding: .day, value: -Int(daysAgo), to: Date()) ?? Date()
        }
    }

    private static func createSamplePlankEntries(in context: NSManagedObjectContext) {
        let calendar = Calendar.current
        let today = Date()
        for dayOffset in 0..<14 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let variance = Double.random(in: 0...1)
            if variance > 0.2 {
                let duration = Double(Int.random(in: 30...180))
                _ = PlankEntry(context: context, durationSeconds: duration, date: date)
            }
        }
    }
    
    private static func createDefaultSettings(in context: NSManagedObjectContext) {
        _ = AppSettings.defaultSettings(context: context)
    }
    
    // MARK: - Unit Testing Helpers
    
    static func createMinimalTestData(in context: NSManagedObjectContext) -> (tasks: [Task], settings: AppSettings) {
        let testTasks = [
            Task(context: context, title: "Test Task 1"),
            Task(context: context, title: "Test Task 2"),
            Task(context: context, title: "Test Task 3")
        ]
        
        let settings = AppSettings.defaultSettings(context: context)
        
        return (tasks: testTasks, settings: settings)
    }
    
    static func createStreakTestData(in context: NSManagedObjectContext) -> Task {
        let task = Task(context: context, title: "Streak Test Task", category: .health, weight: .low)
        
        let calendar = Calendar.current
        let today = Date()
        
        // Create a 7-day streak ending today
        for i in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            
            for period in Period.allCases {
                let completion = Completion(context: context, date: date, period: period, progressUnits: task.weightEnum.requiredUnits)
                completion.task = task
            }
        }
        
        return task
    }
}

// MARK: - Preview Helpers

extension TaskViewModel {
    static func createPreviewViewModel() -> TaskViewModel {
        let previewController = PersistenceController.shared
        let viewModel = TaskViewModel(persistenceController: previewController)
        
        // Create sample data synchronously for preview
        SampleData.createSampleData(in: previewController.context)
        viewModel.loadTasks()
        viewModel.loadOneOffTodos()
        viewModel.loadSettings()
        
        return viewModel
    }
}

// MARK: - Unit Test Helpers

#if DEBUG
extension SampleData {
    static func calculateExpectedCompletionRate(for task: Task, days: Int) -> Double {
        // This is a helper function for unit tests to verify streak calculation logic
        let totalOpportunities = days * Period.allCases.count
        let requiredUnits = task.weightEnum.requiredUnits
        let completedCount = task.completionsArray.filter { $0.progressUnitsValue >= requiredUnits }.count
        return totalOpportunities > 0 ? Double(completedCount) / Double(totalOpportunities) : 0.0
    }
    
    static func createTaskWithSpecificCompletions(
        title: String,
        completionDates: [(Date, Period, Bool)], // (date, period, completed)
        in context: NSManagedObjectContext
    ) -> Task {
        let task = Task(context: context, title: title, category: .general, weight: .low)
        
        for (date, period, completed) in completionDates {
            let progress = completed ? task.weightEnum.requiredUnits : 0
            let completion = Completion(context: context, date: date, period: period, progressUnits: progress)
            completion.task = task
        }
        
        return task
    }
}
#endif
