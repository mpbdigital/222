import ActivityKit
import Foundation

struct EventAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var timeRemaining: String
        var emoji: String
    }

    var startDate: Date
    var eventDate: Date
    var title: String
    var originalDate: Date
    var bellActivated: Bool
    var isBirthday: Bool
}

@MainActor
class LiveActivityManager {
    static let shared = LiveActivityManager()

    private static let activityIdKey = "LiveActivityID"

    private var activity: Activity<EventAttributes>?
    private var currentEmoji: String = ""
    private var updateTimer: Timer?

    private init() {
        if let storedId = UserDefaults.standard.string(forKey: Self.activityIdKey),
           let existing = Activity<EventAttributes>.activities.first(where: { $0.id == storedId }) {
            activity = existing
            currentEmoji = existing.contentState.emoji
            startUpdatingEvery15Seconds(
                to: existing.attributes.eventDate,
                originalDate: existing.attributes.originalDate,
                bellActivated: existing.attributes.bellActivated
            )
            let finalEmoji: String
            if !existing.contentState.emoji.isEmpty {
                finalEmoji = existing.contentState.emoji
            } else if existing.attributes.isBirthday && Calendar.current.isDateInToday(existing.attributes.originalDate) {
                finalEmoji = "\u{1F382}"
            } else {
                finalEmoji = ""
            }
            scheduleAutoEnd(for: existing, finalEmoji: finalEmoji)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.activityIdKey)
        }
    }

    func startActivity(title: String, eventDate: Date, creationDate: Date, emoji: String, originalDate: Date, bellActivated: Bool, isBirthday: Bool) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities are not enabled.")
            return
        }

        if let existing = activity {
            if existing.attributes.title == title &&
               existing.attributes.eventDate == eventDate &&
               existing.contentState.emoji == emoji {
                print("ℹ️ Live Activity already running")
                return
            } else {
                Task { await existing.end(dismissalPolicy: .immediate) }
                updateTimer?.invalidate()
                activity = nil
                UserDefaults.standard.removeObject(forKey: Self.activityIdKey)
            }
        }

        currentEmoji = emoji
        let now = Date()
        let startDate = creationDate

        // Если это день рождения, обнуляем время до 00:00
        var adjustedEventDate = eventDate
        if isBirthday {
            let calendar = Calendar.current
            adjustedEventDate = calendar.startOfDay(for: eventDate)
        }

        let timeLeft = adjustedEventDate.timeIntervalSince(now)
        let timeString = formatTimeRemaining(timeLeft)

        let attributes = EventAttributes(
            startDate: startDate,
            eventDate: adjustedEventDate,
            title: title,
            originalDate: originalDate,
            bellActivated: bellActivated,
            isBirthday: isBirthday
        )

        let state = EventAttributes.ContentState(
            timeRemaining: timeString,
            emoji: emoji
        )

        let content = ActivityContent(state: state, staleDate: adjustedEventDate)

        do {
            activity = try Activity<EventAttributes>.request(
                attributes: attributes,
                content: content
            )
            UserDefaults.standard.set(activity?.id, forKey: Self.activityIdKey)
            print("✅ Live Activity started")

            if let activity = activity {
                let finalEmoji: String
                if !emoji.isEmpty {
                    finalEmoji = emoji
                } else if isBirthday && Calendar.current.isDateInToday(originalDate) {
                    finalEmoji = "\u{1F382}"
                } else {
                    finalEmoji = ""
                }
                scheduleAutoEnd(for: activity, finalEmoji: finalEmoji)
            }

            startUpdatingEvery15Seconds(to: adjustedEventDate, originalDate: originalDate, bellActivated: bellActivated)
        } catch {
            print("❌ Failed to start Live Activity: \(error)")
        }
    }

    private func startUpdatingEvery15Seconds(to eventDate: Date, originalDate: Date, bellActivated: Bool) {
        updateTimer?.invalidate()

        // Обновляем реже и полагаемся на системные таймеры
        updateTimer = Timer.scheduledTimer(withTimeInterval: 5 * 60, repeats: true) { [weak self] _ in
            guard let self, let activity = self.activity else { return }

            let now = Date()
            let timeLeft = eventDate.timeIntervalSince(now)

            if timeLeft <= 0 {
                Task { await activity.end(dismissalPolicy: .immediate) }
                self.updateTimer?.invalidate()
                print("🎉 Событие началось! Активность завершена.")
                return
            }

            let timeString = self.formatTimeRemaining(timeLeft)

            let updatedState = EventAttributes.ContentState(
                timeRemaining: timeString,
                emoji: self.currentEmoji
            )

            let content = ActivityContent(state: updatedState, staleDate: eventDate)

            Task {
                do {
                    try await activity.update(content)
                    print("🔁 Обновлено: \(timeString)")
                } catch {
                    print("⚠️ Не удалось обновить Live Activity: \(error)")
                }
            }
        }
    }

    /// Завершает Live Activity ровно в момент начала события
    private func scheduleAutoEnd(
        for activity: Activity<EventAttributes>,
        finalEmoji: String
    ) {
        let finalState = EventAttributes.ContentState(
            timeRemaining: NSLocalizedString("activity.now", comment: "Now"),
            emoji: finalEmoji
        )
        let finalContent = ActivityContent(state: finalState, staleDate: nil)

        Task {
            let t0 = activity.attributes.eventDate
            try? await activity.end(finalContent,
                                   dismissalPolicy: .after(t0))
        }
    }

    func updateEmoji(_ emoji: String) {
        currentEmoji = emoji
        guard let activity = activity else { return }

        let now = Date()
        let timeLeft = activity.attributes.eventDate.timeIntervalSince(now)
        let timeString = formatTimeRemaining(timeLeft)
        let state = EventAttributes.ContentState(timeRemaining: timeString, emoji: emoji)
        let content = ActivityContent(state: state, staleDate: activity.attributes.eventDate)

        Task {
            do {
                try await activity.update(content)
            } catch {
                print("⚠️ Не удалось обновить Live Activity: \(error)")
            }
        }
    }

    func endActivity() {
        Task {
            await activity?.end(dismissalPolicy: .immediate)
            updateTimer?.invalidate()
            UserDefaults.standard.removeObject(forKey: Self.activityIdKey)
            activity = nil
            print("⛔️ Live Activity manually ended.")
        }
    }

    private func formatTimeRemaining(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60

        if hours > 0 {
            return "\(hours)ч \(minutes)м"
        } else if minutes > 0 {
            return "\(minutes)м \(secs)с"
        } else {
            return "\(secs)сек"
        }
    }
}

