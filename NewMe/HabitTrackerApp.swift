import SwiftUI
import CoreData
import UserNotifications

@main
@available(iOS 14.0, *)
struct HabitTrackerApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var taskViewModel = TaskViewModel()
    @StateObject private var notificationManager = NotificationManager.shared
    
    init() {
        // Setup notification categories
        NotificationManager.setupNotificationCategories()
        
        // Setup notification delegate for handling taps
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.context)
                .environmentObject(taskViewModel)
                .environmentObject(notificationManager)
        }
    }
}

// MARK: - Notification Delegate

class NotificationDelegate: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    
    @Published var shouldPresentChecklist = false
    @Published var checklistPeriod: Period = .morning
    
    override init() {
        super.init()
    }
    
    // Handle notification tap when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound])
        } else {
            completionHandler([.alert, .sound])
        }
    }
    
    // Handle notification response (tap)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        switch response.actionIdentifier {
        case "QUICK_CHECK":
            // Quick check action tapped
            if let periodString = userInfo["period"] as? String,
               let period = Period(rawValue: periodString) {
                DispatchQueue.main.async {
                    self.checklistPeriod = period
                    self.shouldPresentChecklist = true
                }
            }
            
        case UNNotificationDefaultActionIdentifier:
            // Notification itself was tapped
            if let periodString = userInfo["period"] as? String,
               let period = Period(rawValue: periodString) {
                DispatchQueue.main.async {
                    self.checklistPeriod = period
                    self.shouldPresentChecklist = true
                }
            }
            
        case "LATER":
            // Remind later action - schedule another notification in 1 hour
            scheduleReminderIn1Hour(for: userInfo)
            
        default:
            break
        }
        
        completionHandler()
    }
    
    private func scheduleReminderIn1Hour(for userInfo: [AnyHashable: Any]) {
        guard let periodString = userInfo["period"] as? String,
              let period = Period(rawValue: periodString) else { return }
        
        let content = UNMutableNotificationContent()
        content.title = period == .morning ? "Morning Reminder ⏰" : "Evening Reminder ⏰"
        content.body = "Don't forget to check off your \(period.displayName.lowercased()) habits!"
        content.sound = .default
        content.categoryIdentifier = "HABIT_REMINDER"
        content.userInfo = userInfo
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: false) // 1 hour
        let request = UNNotificationRequest(
            identifier: "\(period.rawValue)-reminder-delayed-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule delayed reminder: \(error)")
            }
        }
    }
}