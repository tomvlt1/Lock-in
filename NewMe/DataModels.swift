import CoreData
import Foundation
import SwiftUI

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
        return !completion.skipped
    }
    
    /// Calculate completion rate for the last N days
    func completionRate(for days: Int) -> Double {
        let calendar = Calendar.current
        let today = Date()
        var totalOpportunities = 0
        var completedCount = 0
        
        for i in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            
            for period in Period.allCases {
                if isApplicable(for: period) {
                    totalOpportunities += 1
                    if isCompleted(for: date, period: period) {
                        completedCount += 1
                    }
                }
            }
        }
        
        return totalOpportunities > 0 ? Double(completedCount) / Double(totalOpportunities) : 0.0
    }
    
    /// Calculate skip rate for analytics
    var skipRate: Double {
        let totalCompletions = completionsArray.count
        guard totalCompletions > 0 else { return 0.0 }
        let skippedCount = completionsArray.filter { $0.skipped }.count
        return Double(skippedCount) / Double(totalCompletions)
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
    
    /// Check if task is applicable for a specific period
    func isApplicable(for period: Period) -> Bool {
        return selectedPeriods.contains(period)
    }
    
    /// Convenience initializer
    convenience init(context: NSManagedObjectContext, title: String, periods: Set<Period> = [.morning, .evening]) {
        self.init(context: context)
        self.id = UUID()
        self.title = title
        self.created = Date()
        self.archived = false
        self.selectedPeriods = periods
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
    
    /// Convenience initializer
    convenience init(context: NSManagedObjectContext, date: Date, period: Period, skipped: Bool = false) {
        self.init(context: context)
        self.date = date
        self.periodEnum = period
        self.skipped = skipped
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
    convenience init(context: NSManagedObjectContext, title: String) {
        self.init(context: context)
        self.id = UUID()
        self.title = title
        self.created = Date()
        self.completed = false
        self.statusEnum = .pending
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

// MARK: - AppSettings Entity Extension

extension AppSettings {
    static func defaultSettings(context: NSManagedObjectContext) -> AppSettings {
        let settings = AppSettings(context: context)
        settings.morningReminderTime = Period.morning.defaultTime
        settings.eveningReminderTime = Period.evening.defaultTime
        settings.notificationsEnabled = true
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