import ActivityKit
import WidgetKit
import SwiftUI

private extension ActivityViewContext<EventAttributes> {
    var displayEmoji: String {
        if !state.emoji.isEmpty {
            return state.emoji
        } else if attributes.isBirthday && Calendar.current.isDateInToday(attributes.originalDate) {
            return "\u{1F382}"
        }
        return ""
    }
}

struct EventAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var timeRemaining: String
        var emoji: String
    }

    var title: String
    var startDate: Date
    var eventDate: Date
    var originalDate: Date
    var bellActivated: Bool
    var isBirthday: Bool
}

struct LockScreenView: View {
    let context: ActivityViewContext<EventAttributes>

    var body: some View {
        WidgetEventCardView(
            title: context.attributes.title,
            emoji: context.displayEmoji,
            eventDate: context.attributes.eventDate,
            originalDate: context.attributes.originalDate,
            isBirthday: context.attributes.isBirthday,
            bellActivated: context.attributes.bellActivated,
            showProgress: false
        )
    }
}

struct SmartStackView: View {
    let context: ActivityViewContext<EventAttributes>
    @State private var timerBackgroundColor: Color = .blue

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 4) {
                if !context.displayEmoji.isEmpty {
                    Text(context.displayEmoji)
                        .font(.system(size: 26))
                        .frame(maxHeight: .infinity, alignment: .center)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.title)
                        .font(.system(size: 14, weight: .bold))
                        .lineLimit(1)
                        .foregroundColor(.white)

                    Text(context.attributes.eventDate, style: .date)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)

                    HStack(spacing: 6) {
                        if isBirthday {
                            if let age = getAge(for: context.attributes.originalDate) {
                                Text(String(format: NSLocalizedString("event.age_prefix", comment: ""), age))
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                        } else {
                            Text(context.attributes.eventDate, style: .time)
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }

                        if context.attributes.bellActivated {
                            Image(systemName: "bell.fill")
                                .resizable()
                                .frame(width: 12, height: 12)
                                .foregroundColor(.yellow)
                                .padding(.trailing, 5)
                        }

                        Spacer()

                        if isBirthday && isTodayBirthday(eventDate: context.attributes.originalDate) {
                            Text(NSLocalizedString("event.birthday_today", comment: ""))
                                .frame(minWidth: 70)
                                .monospacedDigit()
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 6)
                                .background(Color.green.opacity(0.8))
                                .cornerRadius(5)
                        } else if let futureDate = getFutureDate(for: context.attributes.eventDate) {
                            Text(futureDate, style: .relative)
                                .frame(minWidth: 70, alignment: .center)
                                .monospacedDigit()
                                .multilineTextAlignment(.center)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 6)
                                .background(timerBackgroundColor)
                                .cornerRadius(5)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .cornerRadius(8)
        .shadow(radius: 2)
        .onAppear {
            updateTimerColor()
        }
    }

    private var isBirthday: Bool {
        context.attributes.isBirthday
    }

    private func isTodayBirthday(eventDate: Date) -> Bool {
        let calendar = Calendar.current
        let todayComponents = calendar.dateComponents([.month, .day], from: Date())
        let eventComponents = calendar.dateComponents([.month, .day], from: eventDate)
        return todayComponents.month == eventComponents.month &&
               todayComponents.day == eventComponents.day
    }

    private func getFutureDate(for eventDate: Date) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        if isBirthday {
            var nextBirthday = eventDate
            while nextBirthday < now {
                nextBirthday = calendar.date(byAdding: .year, value: 1, to: nextBirthday) ?? nextBirthday
            }
            return nextBirthday
        } else {
            return eventDate > now ? eventDate : nil
        }
    }

    private func getAge(for birthDate: Date) -> Int? {
        let calendar = Calendar.current
        let now = Date()
        let ageComponents = calendar.dateComponents([.year], from: birthDate, to: now)
        return ageComponents.year
    }

    private func updateTimerColor() {
        if !isBirthday, context.attributes.eventDate < Date() {
            timerBackgroundColor = .gray
        }
    }
}

struct ActivityContentView: View {
    @Environment(\.activityFamily) private var family
    let context: ActivityViewContext<EventAttributes>

    var body: some View {
        switch family {
        case .small:
            SmartStackView(context: context)
        case .medium:
            LockScreenView(context: context)
        default:
            LockScreenView(context: context)
        }
    }
}

struct LiveActivityWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: EventAttributes.self) { context in
            ActivityContentView(context: context)
        } dynamicIsland: { context in
            // 🟨 Dynamic Island UI
            return DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    WidgetEventCardView(
                        title: context.attributes.title,
                        emoji: context.displayEmoji,
                        eventDate: context.attributes.eventDate,
                        originalDate: context.attributes.originalDate,
                        isBirthday: context.attributes.isBirthday,
                        bellActivated: context.attributes.bellActivated,
                        showProgress: false
                    )
                }
            } compactLeading: {
                StaticCircularProgressView(
                    start: context.attributes.startDate,
                    end: context.attributes.eventDate,
                    emoji: context.displayEmoji,
                    isBirthday: context.attributes.isBirthday,
                    size: 22
                )
            } compactTrailing: {
                EmptyView()
            } minimal: {
                // привет
                if !context.displayEmoji.isEmpty {
                    Text(context.displayEmoji)
                }
            }
          //  .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.blue)
        }
        .supplementalActivityFamilies([.small])
    }
}

struct StaticCircularProgressView: View {
    let start: Date
    let end: Date
    let emoji: String
    let isBirthday: Bool
    let size: CGFloat

    private var progress: Double {
        let now = Date()
        let total = end.timeIntervalSince(start)
        let elapsed = now.timeIntervalSince(start)
        return min(max(elapsed / total, 0), 1)
    }

    var body: some View {
        ZStack {
            ProgressView(value: progress)
                .progressViewStyle(.circular)
                .tint(.blue)
                .frame(width: size, height: size)

            if !emoji.isEmpty {
                Text(emoji)
                    .font(.system(size: size * 0.4))
            }
        }
    }
}

struct WidgetEventCardView: View {
    let title: String
    let emoji: String
    let eventDate: Date
    let originalDate: Date?
    let isBirthday: Bool
    let bellActivated: Bool
    let showProgress: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if showProgress {
                StaticCircularProgressView(
                    start: Date(),
                    end: eventDate,
                    emoji: emoji,
                    isBirthday: isBirthday,
                    size: 40
                )
            } else if !emoji.isEmpty {
                Text(emoji)
                    .font(.system(size: 40))
                    .frame(maxHeight: .infinity, alignment: .center)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        if isBirthday, let originalDate {
                            Text(originalDate, format: .dateTime.day().month())
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if let age = calculateAge(from: originalDate) {
                                Text(String(format: NSLocalizedString("event.age_prefix", comment: ""), age))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text(eventDate, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if Calendar.current.dateComponents([.hour, .minute], from: eventDate).hour != 0 {
                                Text(eventDate, style: .time)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Spacer()

                    if bellActivated {
                        Image(systemName: "bell.fill")
                            .resizable()
                            .frame(width: 12, height: 12)
                            .foregroundColor(.yellow)
                            .padding(.trailing, 5)
                    }

                    if isBirthday && isBirthdayToday(originalDate ?? eventDate) {
                        Text(NSLocalizedString("event.birthday_today", comment: ""))
                            .frame(width: 130, height: 20)
                            .monospacedDigit()
                            .multilineTextAlignment(.center)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .font(.footnote)
                            .padding(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
                            .background(Color.green.opacity(0.8))
                            .cornerRadius(8)
                    } else {
                        Text(eventDate, style: .relative)
                            .frame(width: 120, height: 20)
                            .monospacedDigit()
                            .multilineTextAlignment(.center)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .font(.footnote)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.8))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground).opacity(0.2))
        .cornerRadius(12)
    }

    private func isBirthdayToday(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let today = Date()

        let birthdayComponents = calendar.dateComponents([.day, .month], from: date)
        let todayComponents = calendar.dateComponents([.day, .month], from: today)

        return birthdayComponents.day == todayComponents.day &&
               birthdayComponents.month == todayComponents.month
    }

    private func calculateAge(from birthDate: Date) -> Int? {
        let calendar = Calendar.current
        let now = Date()
        let ageComponents = calendar.dateComponents([.year], from: birthDate, to: now)
        return ageComponents.year
    }

}

// ✅ Превью
extension EventAttributes {
    fileprivate static var preview: EventAttributes {
        EventAttributes(
            title: "День рождения Паши",
            startDate: Date().addingTimeInterval(-3600),
            eventDate: Date().addingTimeInterval(3600),
            originalDate: Calendar.current.date(from: DateComponents(year: 1992, month: 12, day: 14))!,
            bellActivated: true,
            isBirthday: true
        )
    }
}

extension EventAttributes.ContentState {
    fileprivate static var preview1: EventAttributes.ContentState {
        EventAttributes.ContentState(timeRemaining: "2ч 14м", emoji: "🎉")
    }

    fileprivate static var preview2: EventAttributes.ContentState {
        EventAttributes.ContentState(timeRemaining: "59сек", emoji: "")
    }
}

#Preview("Lock Screen", as: .content,
         using: EventAttributes.preview) {
    LiveActivityWidgetLiveActivity()
} contentStates: {
    EventAttributes.ContentState.preview1
}

#Preview("Smart Stack", as: .content,
         using: EventAttributes.preview) {
    LiveActivityWidgetLiveActivity()
} contentStates: {
    EventAttributes.ContentState.preview1
}

