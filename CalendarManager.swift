import EventKit
import Foundation

final class CalendarManager {
    static let shared = CalendarManager()
    private let eventStore = EKEventStore()
    
    private init() {}
    
    func requestCalendarAccess(completion: @escaping (Bool) -> Void) {
        eventStore.requestAccess(to: .event) { granted, error in
            if let error = error {
                print("Calendar access error: \(error)")
            }
            completion(granted)
        }
    }
}
