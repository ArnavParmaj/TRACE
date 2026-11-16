import Foundation
import UserNotifications

/// Local notifications for documents and day-based service (S17). Km-based service needs
/// no notification: the odometer only moves when typed in, on the screen that shows it
/// due (decision 61).
enum Reminders {
    struct Planned: Equatable {
        let id: String
        let fireAt: Date
        let body: String
    }

    static func plan(documents: [VehicleDocument], tasks: [ServiceTask], now: Date,
                     soonShare: Double = 0.15, calendar: Calendar = .current) -> [Planned] {
        func nineAM(_ day: Date, plus days: Int) -> Date? {
            calendar.date(byAdding: .day, value: days, to: day)
                .flatMap { calendar.date(bySettingHour: 9, minute: 0, second: 0, of: $0) }
        }
        func days(_ n: Int) -> String { n == 1 ? "1 day" : "\(n) days" }

        var out: [Planned] = []
        for doc in documents {
            let name = doc.kind.label
            for lead in Set(doc.reminderDaysBefore) where lead > 0 {
                if let at = nineAM(doc.expiresOn, plus: -lead) {
                    out.append(Planned(id: "doc-\(doc.id)-\(lead)", fireAt: at, body: "\(name) expires in \(days(lead))"))
                }
            }
            if let at = nineAM(doc.expiresOn, plus: 0) {
                out.append(Planned(id: "doc-\(doc.id)-0", fireAt: at, body: "\(name) expires today"))
            }
        }
        for task in tasks where task.isActive {
            if let until = task.snoozedUntil, let at = nineAM(until, plus: 0), at > now {
                out.append(Planned(id: "task-\(task.id)-snooze", fireAt: at, body: "\(task.label) was snoozed, check it"))
            }
            guard let interval = task.intervalDays, interval > 0, let last = task.lastDoneAt else { continue }
            let soon = Due.soonDays(interval, share: soonShare)
            let quietUntil = task.snoozedUntil ?? .distantPast   // no reminder inside a snooze
            if let at = nineAM(last, plus: interval - soon), at >= quietUntil {
                out.append(Planned(id: "task-\(task.id)-soon", fireAt: at, body: "\(task.label) due in \(days(soon))"))
            }
            if let at = nineAM(last, plus: interval + 1), at >= quietUntil {
                out.append(Planned(id: "task-\(task.id)-over", fireAt: at, body: "\(task.label) overdue"))
            }
        }
        return out.filter { $0.fireAt > now }.sorted { $0.fireAt < $1.fireAt }
    }

    /// Replaces every pending reminder with a fresh plan. iOS keeps at most 64; the
    /// soonest win.
    static func apply(_ plan: [Planned], calendar: Calendar = .current) async {
        let center = UNUserNotificationCenter.current()
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
        center.removeAllPendingNotificationRequests()
        for item in plan.prefix(64) {
            let content = UNMutableNotificationContent()
            content.body = item.body
            content.sound = .default
            let when = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: item.fireAt)
            try? await center.add(UNNotificationRequest(
                identifier: item.id, content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: false)))
        }
    }

    /// The widget's LOG confirmation (decision 93). Silent, and one at a time: a second log replaces the first.
    /// Shows only once notifications are allowed; the widget's own LOGGED label does not depend on it.
    static func confirmLogged(at time: Date = .now) {
        let content = UNMutableNotificationContent()
        content.title = "Logged"
        content.body = "Draft saved at \(time.formatted(date: .omitted, time: .shortened)). Complete it in TRACE."
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "log-confirm", content: content, trigger: nil))
    }

    /// Re-plans from the store. Call after any task or document change, and on launch.
    @MainActor
    static func refresh(_ garage: Garage) {
        guard let bike = try? garage.bike() else {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()   // bike removed
            return
        }
        guard let tasks = try? garage.tasks(bike), let docs = try? garage.documents(bike) else { return }
        let plan = plan(documents: docs, tasks: tasks, now: .now, soonShare: Preferences.soonShare)
        // Ask for permission only once there is something to remind about.
        guard !plan.isEmpty || !docs.isEmpty else { return }
        Task { await apply(plan) }
    }
}
