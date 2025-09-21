import UserNotifications
import SwiftUI
import CoreData
import Foundation

@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var permissionStatus: UNAuthorizationStatus = .notDetermined
    
    private init() {
        checkPermissionStatus()
    }
    
    // MARK: - Permission Management
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Failed to request notification permission: \(error)")
                DispatchQueue.main.async {
                    self.checkPermissionStatus()
                    completion(false)
                }
                return
            }
            
            DispatchQueue.main.async {
                self.checkPermissionStatus()
                completion(granted)
            }
        }
    }
    
    func checkPermissionStatus() {
        // Use completion handler approach for iOS 14 compatibility
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.permissionStatus = settings.authorizationStatus
            }
        }
    }
    
    
    // MARK: - Notification Scheduling
    
    func scheduleHabitReminders(morningTime: Date, eveningTime: Date) {
        // Cancel existing notifications
        cancelHabitReminders()
        
        // Use legacy approach for iOS 14 compatibility
        scheduleRepeatingNotificationLegacy(
            identifier: "morning-reminder",
            time: morningTime,
            title: "Morning Habits",
            body: "Time to check off your morning habits",
            period: .morning
        )
        
        scheduleRepeatingNotificationLegacy(
            identifier: "evening-reminder", 
            time: eveningTime,
            title: "Evening habits",
            body: "How did your evening habits go?",
            period: .evening
        )
    }
    
    
    private func scheduleRepeatingNotificationLegacy(
        identifier: String,
        time: Date,
        title: String,
        body: String,
        period: Period
    ) {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "HABIT_REMINDER"
        content.userInfo = ["period": period.rawValue]
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: true
        )
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }
    
    func cancelHabitReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["morning-reminder", "evening-reminder"]
        )
    }
    
    // MARK: - Recovery Banner Logic
    
    func shouldShowRecoveryBanner() -> (show: Bool, period: Period?, date: Date?) {
        let calendar = Calendar.current
        let now = Date()
        
        // Check if we missed yesterday evening
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now) {
            let lastEveningCutoff = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: yesterday)
            let thisEveningStart = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: now)
            
            if let cutoff = lastEveningCutoff,
               let start = thisEveningStart,
               now > cutoff && now < start {
                return (true, .evening, yesterday)
            }
        }
        
        // Check if we missed this morning
        let thisMorningCutoff = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now)
        if let cutoff = thisMorningCutoff, now > cutoff {
            let morningStart = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: now)
            if let start = morningStart, now > start {
                return (true, .morning, now)
            }
        }
        
        return (false, nil, nil)
    }
    
    // MARK: - Live Activity Support (iOS 16.1+)
    
    // Live Activity functions removed for iOS 14 compatibility
    // func startLiveActivity(for tasks: [Task], period: Period) {
    //     // TODO: Implement Live Activity when ActivityKit is configured
    // }
    
    // func endLiveActivity() {
    //     // TODO: End the active Live Activity
    // }
}

// MARK: - Notification Categories

extension NotificationManager {
    static func setupNotificationCategories() {
        let quickCheckAction = UNNotificationAction(
            identifier: "QUICK_CHECK",
            title: "Quick Check",
            options: [.foreground]
        )
        
        let laterAction = UNNotificationAction(
            identifier: "LATER",
            title: "Remind Later",
            options: []
        )
        
        let habitCategory = UNNotificationCategory(
            identifier: "HABIT_REMINDER",
            actions: [quickCheckAction, laterAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([habitCategory])
    }
}
