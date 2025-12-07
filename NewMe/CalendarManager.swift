import EventKit
import Foundation

/// Centralizes all Apple Calendar interactions for one-off todos.
final class CalendarManager: ObservableObject {
    static let shared = CalendarManager()

    private let eventStore = EKEventStore()
    private let metadataPrefix = "NewMeTodo:"

    @Published private(set) var authorizationStatus: EKAuthorizationStatus

    private init() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    func requestCalendarAccess(completion: @escaping (Bool) -> Void) {
        let currentStatus = EKEventStore.authorizationStatus(for: .event)

        if currentStatus == .authorized {
            DispatchQueue.main.async {
                self.authorizationStatus = currentStatus
                completion(true)
            }
            return
        }

        eventStore.requestAccess(to: .event) { [weak self] granted, error in
            if let error = error {
                print("Calendar access error: \(error)")
            }
            DispatchQueue.main.async {
                self?.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                completion(granted)
            }
        }
    }

    func addOrUpdateTodo(id: UUID, title: String, dueDate: Date, isCompleted: Bool) {
        guard authorizationStatus == .authorized else { return }

        // Remove any existing event before creating the new one so we avoid duplicates.
        removeTodo(id: id, dueDate: dueDate)

        let event = EKEvent(eventStore: eventStore)
        event.calendar = eventStore.defaultCalendarForNewEvents

        if isCompleted {
            event.title = "✅ \(title)"
            event.notes = "\(metadataPrefix)\(id.uuidString)|status:completed"
        } else {
            event.title = "📝 \(title)"
            event.notes = "\(metadataPrefix)\(id.uuidString)|status:pending"
        }

        // Create an all-day block for the due date.
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: dueDate)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(3600)
        event.startDate = start
        event.endDate = end
        event.isAllDay = true

        do {
            try eventStore.save(event, span: .thisEvent)
            print("Calendar event saved for todo \(id.uuidString)")
        } catch {
            print("Failed to save calendar event for todo \(id.uuidString): \(error)")
        }
    }

    func removeTodo(id: UUID, dueDate: Date) {
        guard authorizationStatus == .authorized else { return }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: dueDate)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(3600)

        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = eventStore.events(matching: predicate)

        for event in events where eventContainsMetadata(event, id: id) {
            do {
                try eventStore.remove(event, span: .thisEvent)
                print("Removed calendar event for todo \(id.uuidString)")
            } catch {
                print("Failed to remove calendar event for todo \(id.uuidString): \(error)")
            }
        }
    }

    private func eventContainsMetadata(_ event: EKEvent, id: UUID) -> Bool {
        guard let notes = event.notes else { return false }
        return notes.contains("\(metadataPrefix)\(id.uuidString)")
    }
}
