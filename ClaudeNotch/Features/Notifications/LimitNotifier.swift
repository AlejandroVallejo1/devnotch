import Foundation
import UserNotifications

/// Sends a native notification when usage crosses the configured threshold
/// (once per session and once per week).
final class LimitNotifier {
    private let preferences: Preferences
    private let center = UNUserNotificationCenter.current()

    private var notifiedSessionStart: Date?
    private var notifiedWeekStart: Date?

    init(preferences: Preferences) {
        self.preferences = preferences
        requestAuthorization()
    }

    private func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func check(snapshot: UsageSnapshot) {
        let threshold = Double(preferences.notifyAtPercent) / 100.0

        if snapshot.sessionPercent >= threshold, notifiedSessionStart != snapshot.sessionStart {
            notifiedSessionStart = snapshot.sessionStart
            send(
                title: "Claude session at \(Int(snapshot.sessionPercent * 100))%",
                body: "Reset in \(FormatHelpers.relativeDuration(snapshot.sessionResetsIn ?? 0))"
            )
        }

        // Weekly: use the Monday of the current week as a stable key.
        let weekAnchor = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start
        if snapshot.weeklyPercent >= threshold, notifiedWeekStart != weekAnchor {
            notifiedWeekStart = weekAnchor
            send(
                title: "Claude weekly at \(Int(snapshot.weeklyPercent * 100))%",
                body: "Pacing to hit the weekly limit. Consider slowing down or switching models."
            )
        }
    }

    private func send(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(request)
    }
}
