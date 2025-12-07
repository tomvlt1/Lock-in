import CoreData
import Foundation
import SwiftUI

// MARK: - Task Metadata

enum TaskCategory: String, CaseIterable, Identifiable, Codable {
    case general
    case health
    case work
    case learning
    case personal
    case wellness
    case other
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .general: return "General"
        case .health: return "Health"
        case .work: return "Work"
        case .learning: return "Learning"
        case .personal: return "Personal"
        case .wellness: return "Wellness"
        case .other: return "Other"
        }
    }
    
    var color: Color {
        switch self {
        case .general: return .blue
        case .health: return .green
        case .work: return .orange
        case .learning: return .purple
        case .personal: return .pink
        case .wellness: return .mint
        case .other: return .gray
        }
    }
}

enum TaskWeight: String, CaseIterable, Identifiable, Codable {
    case low
    case medium
    case high
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
    
    var requiredUnits: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        }
    }
}

// MARK: - Task Entity Extension

extension Task {
    // MARK: - Computed Properties
    
    /// Get completion for a specific date and period
    func completion(for date: Date, period: Period) -> Completion? {
        let calendar = Calendar.current
        return completionsArray.first { completion in
            calendar.isDate(completion.date ?? Date(), inSameDayAs: date) && completion.periodEnum == period
        }
    }
    
    /// Check if task is completed for a specific date and period
    func isCompleted(for date: Date, period: Period) -> Bool {
        guard let completion = completion(for: date, period: period) else { return false }
        return completion.progressUnitsValue >= weightEnum.requiredUnits
    }
    
    /// Calculate completion rate for the last N days
    func completionRate(for days: Int) -> Double {
        let calendar = Calendar.current
        let today = Date()
        var totalOpportunities = 0.0
        var completedUnits = 0.0
        
        for i in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            
            for period in Period.allCases where isApplicable(for: period) {
                totalOpportunities += 1
                completedUnits += completionContribution(for: date, period: period)
            }
        }
        
        return totalOpportunities > 0 ? completedUnits / totalOpportunities : 0.0
    }
    
    /// Convert Core Data set to array
    var completionsArray: [Completion] {
        return completions?.allObjects as? [Completion] ?? []
    }
    
    /// Get selected periods for this task
    var selectedPeriods: Set<Period> {
        get {
            let periodsString = self.value(forKey: "periods") as? String ?? "morning,evening"
            let periodStrings = periodsString.components(separatedBy: ",")
            return Set(periodStrings.compactMap { Period(rawValue: $0.trimmingCharacters(in: .whitespacesAndNewlines)) })
        }
        set {
            self.setValue(newValue.map { $0.rawValue }.sorted().joined(separator: ","), forKey: "periods")
        }
    }
    
    var categoryEnum: TaskCategory {
        get {
            TaskCategory(rawValue: self.value(forKey: "category") as? String ?? "general") ?? .general
        }
        set {
            self.setValue(newValue.rawValue, forKey: "category")
        }
    }
    
    var weightEnum: TaskWeight {
        get {
            TaskWeight(rawValue: self.value(forKey: "weight") as? String ?? "low") ?? .low
        }
        set {
            self.setValue(newValue.rawValue, forKey: "weight")
        }
    }
    
    /// Check if task is applicable for a specific period
    func isApplicable(for period: Period) -> Bool {
        return selectedPeriods.contains(period)
    }

    /// Fractional credit the task earns for a specific date/period (0-1).
    func completionContribution(for date: Date, period: Period) -> Double {
        guard isApplicable(for: period) else { return 0 }
        let progress = completion(for: date, period: period)?.progressUnitsValue ?? 0
        let required = max(1, weightEnum.requiredUnits)
        return min(1.0, Double(progress) / Double(required))
    }

    /// Average completion fraction across all applicable periods on a date.
    func completionFraction(for date: Date) -> Double {
        let applicable = Period.allCases.filter { isApplicable(for: $0) }
        guard !applicable.isEmpty else { return 0 }
        let total = applicable.reduce(0.0) { $0 + completionContribution(for: date, period: $1) }
        return total / Double(applicable.count)
    }

    /// Returns true if every applicable period is fully completed on the date.
    func isFullyCompleted(on date: Date) -> Bool {
        Period.allCases
            .filter { isApplicable(for: $0) }
            .allSatisfy { completionContribution(for: date, period: $0) >= 1.0 }
    }
    
    /// Convenience initializer
    convenience init(
        context: NSManagedObjectContext,
        title: String,
        periods: Set<Period> = [.morning, .evening],
        category: TaskCategory = .general,
        weight: TaskWeight = .low
    ) {
        self.init(context: context)
        self.id = UUID()
        self.title = title
        self.created = Date()
        self.archived = false
        self.selectedPeriods = periods
        self.categoryEnum = category
        self.weightEnum = weight
    }
}

// MARK: - Completion Entity Extension

extension Completion {
    var periodEnum: Period {
        get {
            return Period(rawValue: period ?? "morning") ?? .morning
        }
        set {
            period = newValue.rawValue
        }
    }
    
    var progressUnitsValue: Int {
        get {
            let stored = Int(self.value(forKey: "progressUnits") as? Int16 ?? 0)
            if stored == 0 && !skipped {
                return task?.weightEnum.requiredUnits ?? TaskWeight.low.requiredUnits
            }
            return max(0, stored)
        }
        set {
            let clamped = max(0, min(3, newValue))
            self.setValue(Int16(clamped), forKey: "progressUnits")
            self.skipped = clamped == 0
        }
    }
    
    /// Convenience initializer
    convenience init(context: NSManagedObjectContext, date: Date, period: Period, progressUnits: Int = 0) {
        self.init(context: context)
        self.date = date
        self.periodEnum = period
        self.progressUnitsValue = progressUnits
    }
}

// MARK: - TodoStatus Enum

enum TodoStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case completed = "completed" 
    case failed = "failed"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }
    
    var icon: String {
        switch self {
        case .pending: return "circle"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .pending: return .gray
        case .completed: return .green
        case .failed: return .red
        }
    }
}

// MARK: - OneOffTodo Entity Extension

extension OneOffTodo {
    convenience init(context: NSManagedObjectContext, title: String, dueDate: Date? = nil) {
        self.init(context: context)
        self.id = UUID()
        self.title = title
        self.created = Date()
        self.completed = false
        self.statusEnum = .pending
        self.dueDate = dueDate
    }

    var statusEnum: TodoStatus {
        get {
            return TodoStatus(rawValue: status ?? "pending") ?? .pending
        }
        set {
            status = newValue.rawValue
            // Update completed boolean for backward compatibility
            completed = (newValue == .completed)
        }
    }

    var isOverdue: Bool {
        guard let dueDate = dueDate else { return false }
        return statusEnum == .pending && dueDate < Date()
    }
}

// MARK: - WeightEntry Entity Extension

extension WeightEntry {
    convenience init(context: NSManagedObjectContext, weight: Double, date: Date = Date()) {
        self.init(context: context)
        self.id = UUID()
        self.weight = weight
        self.date = date
    }
}

// MARK: - PlankEntry Entity Extension

extension PlankEntry {
    convenience init(context: NSManagedObjectContext, durationSeconds: Double, date: Date = Date()) {
        self.init(context: context)
        self.id = UUID()
        self.durationSeconds = durationSeconds
        self.date = date
    }
}

// MARK: - AppSettings Entity Extension

extension AppSettings {
    static func defaultSettings(context: NSManagedObjectContext) -> AppSettings {
        let settings = AppSettings(context: context)
        settings.morningReminderTime = Period.morning.defaultTime
        settings.eveningReminderTime = Period.evening.defaultTime
        settings.notificationsEnabled = true
        settings.calendarSyncEnabled = false
        return settings
    }
}

// MARK: - Period Enum

enum Period: String, CaseIterable, Codable {
    case morning = "morning"
    case evening = "evening"
    
    var displayName: String {
        switch self {
        case .morning: return "Morning"
        case .evening: return "Evening"
        }
    }
    
    var defaultTime: Date {
        let calendar = Calendar.current
        let components = DateComponents(
            hour: self == .morning ? 7 : 21,
            minute: 30
        )
        return calendar.date(from: components) ?? Date()
    }
}

// MARK: - Core Data Stack Helper

class PersistenceController {
    static let shared = PersistenceController()
    
    lazy var container: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "NewMe")
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Core Data error: \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()
    
    var context: NSManagedObjectContext {
        container.viewContext
    }
    
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                fatalError("Core Data save error: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}
