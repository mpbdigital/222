// добавил таймер

import WidgetKit
import SwiftUI
import Foundation
import SwiftData

// MARK: - Data Model

enum EventType: String, Codable { case event, birthday }

struct Event: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var date: Date
    var eventType: EventType
    var emoji: String
    var repeatYearly: Bool = false
    var creationDate: Date = Date()
    var bellActivated: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, name, date, eventType, emoji, repeatYearly, creationDate, bellActivated
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        date = try container.decode(Date.self, forKey: .date)
        eventType = try container.decode(EventType.self, forKey: .eventType)
        emoji = try container.decode(String.self, forKey: .emoji)
        repeatYearly = try container.decodeIfPresent(Bool.self, forKey: .repeatYearly) ?? false
        bellActivated = try container.decodeIfPresent(Bool.self, forKey: .bellActivated) ?? false

        if let decodedCreation = try container.decodeIfPresent(Date.self, forKey: .creationDate) {
            creationDate = decodedCreation
        } else {
            let now = Date()
            let target = nextDate(for: Event(id: id, name: name, date: date, eventType: eventType, emoji: emoji, repeatYearly: repeatYearly), from: now)
            let interval = target.timeIntervalSince(now)
            creationDate = now.addingTimeInterval(-interval)
        }
    }

    init(id: UUID = UUID(), name: String, date: Date, eventType: EventType, emoji: String, repeatYearly: Bool = false, creationDate: Date = Date(), bellActivated: Bool = false) {
        self.id = id
        self.name = name
        self.date = date
        self.eventType = eventType
        self.emoji = emoji
        self.repeatYearly = repeatYearly
        self.creationDate = creationDate
        self.bellActivated = bellActivated
    }
}

enum NotificationType: String, Codable {
    case message
    case sound
}

enum DayOfWeek: String, Codable, CaseIterable {
    case monday, tuesday, wednesday, thursday, friday, saturday, sunday
}

enum Month: String, Codable, CaseIterable {
    case january, february, march, april, may, june, july, august, september, october, november, december
}

enum RepeatInterval: String, Codable, CaseIterable {
    case none, minute1, minute5, minute10, minute15, minute30, minute35, minute40, hour
}

struct ChecklistItem: Identifiable, Codable {
    let id: UUID
    var text: String
    var isCompleted: Bool
}

@Model
class ChecklistItemModel {
    @Attribute(.unique) var id: UUID
    var text: String
    var isCompleted: Bool
    var isEditing: Bool
    var order: Int

    @Relationship var event: EventModel?

    init(id: UUID = UUID(), text: String, isCompleted: Bool = false, isEditing: Bool = false, order: Int = 0, event: EventModel? = nil) {
        self.id = id
        self.text = text
        self.isCompleted = isCompleted
        self.isEditing = isEditing
        self.order = order
        self.event = event
    }

    func toggleCompletion() {
        isCompleted.toggle()
    }
}

// MARK: - Timeline Entry

struct EventEntry: TimelineEntry {
    let date: Date
    let startDate: Date
    let event: Event?
    let isPassed: Bool
}

private extension EventEntry {
    static var preview: EventEntry {
        let now = Date()
        let start = Calendar.current.date(byAdding: .hour, value: -3, to: now)!
        return EventEntry(date: now,
                          startDate: start,
                          event: .preview,
                          isPassed: false)
    }
}



extension Event {
    init(from model: EventModel) {
        self.id = model.id
        self.name = model.name
        self.date = model.date
        self.eventType = model.eventType
        self.emoji = model.emoji
        self.repeatYearly = model.repeatYearly
        self.creationDate = model.creationDate
        self.bellActivated = model.bellActivated
    }
}

private extension Event {
    static var preview: Event {
        let now = Date()
        let target = Calendar.current.date(byAdding: .hour, value: 27, to: now)!
        return Event(name: NSLocalizedString("PREVIEW_EVENT_MEETING", comment: ""),
                     date: target,
                     eventType: .event,
                     emoji: "🎉")
    }
}

@MainActor
final class ComplicationDataManager {
    static let shared = ComplicationDataManager()

    let container: ModelContainer
    let context: ModelContext

    private init() {
        let schema = Schema([EventModel.self])
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) {
            print("[MyComolicationYes] container path: \(groupURL.path)")
            let storeURL = groupURL.appendingPathComponent("Events.store")
            let configuration = ModelConfiguration(schema: schema, url: storeURL)
            if let container = try? ModelContainer(for: schema, configurations: [configuration]) {
                self.container = container
            } else if let fallback = try? ModelContainer(for: schema) {
                self.container = fallback
            } else {
                fatalError("Unable to create SwiftData container")
            }
        } else if let container = try? ModelContainer(for: schema) {
            self.container = container
        } else {
            fatalError("Unable to create SwiftData container")
        }
        self.context = container.mainContext
    }

    func loadAllEvents() -> [Event] {
        let models = (try? context.fetch(FetchDescriptor<EventModel>())) ?? []
        print("🔍 ComplicationDataManager.loadAllEvents — найдено \(models.count) записей")
        for model in models {
            print("    • \(model.name) [\(model.id)]")
        }
        return models.map { Event(from: $0) }
    }
}

// MARK: - Shared Helpers

private let appGroup = "group.com.mpb.momenttimer"

/// \u041c\u0438\u043d\u0438\u043c\u0430\u043b\u044c\u043d\u044b\u0439 \u0448\u0430\u0433 \u043c\u0435\u0436\u0434\u0443 \u0437\u0430\u043f\u0438\u0441\u044f\u043c\u0438 (\u043c\u0438\u043d)
private let kMinStride = 5
/// \u0421\u043a\u043e\u043b\u044c\u043a\u043e \u00ab\u043f\u0443\u0441\u0442\u044b\u0445\u00bb \u043c\u0438\u043d\u0443\u0442 \u0434\u0435\u0440\u0436\u0438\u043c \u043f\u043e\u0441\u043b\u0435 \u0441\u043e\u0431\u044b\u0442\u0438\u044f
private let kAfterEventBuffer = 15
/// \u041c\u0430\u043a\u0441\u0438\u043c\u0443\u043c \u0437\u0430\u043f\u0438\u0441\u0435\u0439 \u0432 \u043e\u0434\u043d\u043e\u043c timeline
private let kEntryLimit = 50

@MainActor
private func loadEvents() -> [Event] {
    let events = ComplicationDataManager.shared.loadAllEvents()
    print("🔄 loadEvents() вернуло \(events.count) объектов")
    return events
}

private func nextDate(for event: Event, from ref: Date) -> Date {
    if event.eventType == .birthday || event.repeatYearly {
        let md = Calendar.current.dateComponents([.month, .day], from: event.date)
        var comp = DateComponents(year: Calendar.current.component(.year, from: ref), month: md.month, day: md.day)
        var candidate = Calendar.current.date(from: comp) ?? event.date
        if candidate < ref { comp.year! += 1; candidate = Calendar.current.date(from: comp) ?? event.date }
        return candidate
    } else {
        return event.date
    }
}

private func buildEntries(for event: Event, now: Date, into entries: inout [EventEntry]) {
    let startDate = event.creationDate
    let eventTime = nextDate(for: event, from: now)
    let minutesToEvent = max(0, Int(eventTime.timeIntervalSince(now) / 60))
    var stride = kMinStride
    while (minutesToEvent + kAfterEventBuffer) / stride > kEntryLimit {
        stride += 1
    }

    var current = now
    while current < eventTime && entries.count < kEntryLimit {
        entries.append(EventEntry(date: current,
                                  startDate: startDate,
                                  event: event,
                                  isPassed: false))
        current = Calendar.current.date(byAdding: .minute, value: stride, to: current)!
    }

    guard entries.count < kEntryLimit else { return }
    entries.append(EventEntry(date: eventTime,
                              startDate: startDate,
                              event: event,
                              isPassed: false))

    current = Calendar.current.date(byAdding: .minute, value: stride, to: eventTime)!
    let bufferEnd = Calendar.current.date(byAdding: .minute, value: kAfterEventBuffer, to: eventTime)!
    while current <= bufferEnd && entries.count < kEntryLimit {
        entries.append(EventEntry(date: current,
                                  startDate: startDate,
                                  event: event,
                                  isPassed: true))
        current = Calendar.current.date(byAdding: .minute, value: stride, to: current)!
    }
}

// MARK: - Timeline Provider

@MainActor
struct EventTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> EventEntry {
        EventEntry.preview
    }

    func getSnapshot(in context: Context, completion: @escaping (EventEntry) -> Void) {
        if context.isPreview {
            completion(.preview)
            return
        }

        let now = Date()
        let entry = EventEntry(date: now, startDate: now, event: nil, isPassed: false)
        print("📦 getSnapshot: отправляем в completion событие: \(entry.event?.name ?? "none")")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EventEntry>) -> Void) {
        let now = Date()
        let events = loadEvents()
            .filter { $0.eventType == .birthday || $0.date >= now || $0.repeatYearly }
            .sorted { nextDate(for: $0, from: now) < nextDate(for: $1, from: now) }
        print("🧩 getTimeline: после фильтрации — \(events.count) событий")
        for event in events {
            print("    • \(event.name) [\(event.id)] — \(event.date)")
        }

        guard !events.isEmpty else {
            print("📦 getTimeline: отправляем в completion пустой список событий")
            completion(Timeline(entries: [EventEntry(date: now, startDate: now, event: nil, isPassed: false)],
                                policy: .after(now.addingTimeInterval(3600))))
            return
        }

        var entries: [EventEntry] = []
        var currentNow = now
        for event in events {
            buildEntries(for: event, now: currentNow, into: &entries)
            guard entries.count < kEntryLimit else { break }
            currentNow = entries.last?.date ?? currentNow
        }

        if entries.count > kEntryLimit {
            entries = Array(entries.prefix(kEntryLimit))
        }

        guard let last = entries.last else {
            completion(Timeline(entries: [EventEntry(date: now, startDate: now, event: nil, isPassed: false)],
                                policy: .after(now.addingTimeInterval(3600))))
            return
        }

        print("🧩 getTimeline: готово \(entries.count) записей, отправляем в WidgetKit")
        let names = entries.compactMap { $0.event?.name }.joined(separator: ", ")
        print("📦 getTimeline: отправляем в completion события: \(names)")
        completion(Timeline(entries: entries,
                            policy: .after(last.date.addingTimeInterval(1))))
    }
}

// MARK: - Time Breakdown for Gauge

private struct GaugeComponents {
    let main: Int
    let unit: String
    let progress: Double
}

private func gaugeComponents(start: Date, now: Date, for event: Event) -> GaugeComponents? {
    let target = nextDate(for: event, from: now)
    let totalInterval = target.timeIntervalSince(start)
    let passedInterval = now.timeIntervalSince(start)

    guard totalInterval > 0 else { return nil }

    var progress = passedInterval / totalInterval
    progress = min(max(progress, 0.01), 1.0)

    let secondsLeft = max(Int(target.timeIntervalSince(now)), 0)
    let days = secondsLeft / 86_400
    let hours = (secondsLeft % 86_400) / 3_600
    let minutes = (secondsLeft % 3_600) / 60
    let seconds = secondsLeft % 60

    if days > 0 {
        return GaugeComponents(main: days, unit: "\(hours)ч", progress: progress)
    } else if hours > 0 {
        return GaugeComponents(main: hours, unit: "\(minutes)м", progress: progress)
    } else if minutes > 0 {
        return GaugeComponents(main: minutes, unit: "\(seconds)с", progress: progress)
    } else {
        return GaugeComponents(main: seconds, unit: "сек", progress: progress)
    }
}

// MARK: - Complication Views
struct EventComplicationEntryView: View {
    let entry: EventEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if family == .accessoryCorner {
            CornerView(entry: entry)
        } else if let event = entry.event {
            switch family {
            case .accessoryCircular:
                CircularGaugeView(entry: entry)

            case .accessoryInline:
                TextVariant(event: event, now: entry.date, isPassed: entry.isPassed)

            case .accessoryRectangular:
                RectangularCardView(entry: entry)

            @unknown default:
                Text("—")
            }
        } else if family == .accessoryCircular {
            VStack(spacing: 2) {
                Image(systemName: "calendar")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                Text(NSLocalizedString("NO_SHORT", comment: "No"))
                    .font(.system(size: 11, weight: .medium))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.system(size: 18))
                    .foregroundColor(.gray)
                Text(NSLocalizedString("NO_EVENTS", comment: "No events"))
                    .font(.system(size: 12, weight: .medium))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}




private struct CircularGaugeView: View {
    let entry: EventEntry
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        guard let event = entry.event else {
            return AnyView(Text("—"))
        }

        if isLuminanceReduced {
            // Упрощённый контент для AOD
            return AnyView(
                Image(systemName: "star.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.yellow)
            )
        }

        if entry.isPassed {
            return AnyView(
                Gauge(value: 1) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(.blue.opacity(0.3))
            )
        } else {
            if let cmp = gaugeComponents(start: entry.startDate, now: entry.date, for: event) {
                return AnyView(
                    ZStack {
                        Gauge(value: cmp.progress, in: 0...1) {
                            EmptyView()
                        }
                        .gaugeStyle(.accessoryCircularCapacity)
                        .tint(.blue)

                        Text(nextDate(for: event, from: entry.date), style: .relative)
                            .font(.system(size: 12, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .truncationMode(.tail)
                            .padding(.horizontal, 6)
                            .frame(maxWidth: 42, minHeight: 20, alignment: .center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                )
            } else {
                return AnyView(Text("—"))
            }
        }
    }
}

// крупный виджет

private struct RectangularCardView: View {
    let entry: EventEntry
    @State private var timerBackgroundColor: Color = .blue

    var body: some View {
        guard let event = entry.event else {
            return AnyView(
                Text(NSLocalizedString("NO_EVENTS", comment: "No events"))
                    .font(.system(size: 12, weight: .medium))
                    .multilineTextAlignment(.center)
            )
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 4) {
                    if !event.emoji.isEmpty {
                        Text(event.emoji)
                            .font(.system(size: 26))
                            .frame(maxHeight: .infinity, alignment: .center)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.name)
                            .font(.system(size: 14, weight: .bold))
                            .lineLimit(1)
                            .foregroundColor(.white)

                        Text(event.date, style: .date)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)

                        HStack(spacing: 6) {
                            if event.eventType == .birthday {
                                if let age = getAge(for: event.date) {
                                    Text("\(age) лет")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }
                            } else {
                                Text(event.date, style: .time)
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }

                            Spacer()

                        if event.eventType == .birthday && isTodayBirthday(eventDate: event.date) {
                            Text("🎂 Сегодня!")
                                .frame(minWidth: 70)
                                .monospacedDigit()
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 6)
                                .background(Color.green.opacity(0.8))
                                .cornerRadius(5)
                        } else if let futureDate = getFutureDate(for: event.date, event: event) {
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
            .overlay(alignment: .topTrailing) {
                if event.bellActivated {
                    Image(systemName: "bell.fill")
                        .resizable()
                        .frame(width: 8, height: 8)
                        .foregroundColor(.yellow)
                        .padding(5)
                }
            }
            .onAppear {
                updateTimerColor(for: event)
            }
        )
    }

    private func isTodayBirthday(eventDate: Date) -> Bool {
        let calendar = Calendar.current
        let todayComponents = calendar.dateComponents([.month, .day], from: Date())
        let eventComponents = calendar.dateComponents([.month, .day], from: eventDate)
        return todayComponents.month == eventComponents.month &&
               todayComponents.day == eventComponents.day
    }

    private func getFutureDate(for eventDate: Date, event: Event) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        if event.eventType == .birthday {
            var nextBirthday = eventDate
            while nextBirthday < now {
                nextBirthday = calendar.date(byAdding: .year, value: 1, to: nextBirthday) ?? nextBirthday
            }
            return nextBirthday
        } else {
            return event.date > now ? event.date : nil
        }
    }

    private func getAge(for birthDate: Date) -> Int? {
        let calendar = Calendar.current
        let now = Date()
        let ageComponents = calendar.dateComponents([.year], from: birthDate, to: now)
        return ageComponents.year
    }

    private func updateTimerColor(for event: Event) {
        if event.eventType != .birthday, event.date < Date() {
            timerBackgroundColor = .gray
        }
    }
}

// боковой виджет
private struct CornerView: View {
    let entry: EventEntry
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        if let event = entry.event {
            Group {
                if isLuminanceReduced {
                    // Упрощённое отображение для режима Always‑On
                    Text(NSLocalizedString("SOON_LABEL", comment: "Скоро"))
                        .font(.system(size: 12, weight: .medium))
                        .widgetCurvesContent()
                        .widgetLabel {
                            Text(event.name)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }
                } else {
                    // Стандартный режим
                    Text(nextDate(for: event, from: entry.date), style: .relative)
                        .font(.system(size: 12, weight: .medium))
                        .widgetCurvesContent() // ✅ Только один изгиб — безопасно
                        .widgetLabel {
                            Text(event.name)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }
                }
            }
        } else {
            Text(NSLocalizedString("NO_SHORT", comment: "No"))
                .widgetCurvesContent()
                .widgetLabel {
                    Text(NSLocalizedString("COMPLICATION_EVENTS_LABEL", comment: ""))
                }
        }
    }
}
// виджет изогнутая линия

private struct TextVariant: View {
    let event: Event
    let now: Date
    let isPassed: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text(event.name)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            if !isPassed {
                Text(nextDate(for: event, from: now), style: .relative)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
    }
}




// MARK: - Widget Definition

@main
struct EventComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "EventComplication", provider: EventTimelineProvider()) { entry in
            if #available(watchOSApplicationExtension 10.0, *) {
                EventComplicationEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                EventComplicationEntryView(entry: entry)
            }
        }
        .configurationDisplayName(NSLocalizedString("COMPLICATION_DISPLAY_NAME", comment: ""))
        .description(NSLocalizedString("COMPLICATION_DISPLAY_DESCRIPTION", comment: ""))
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline, .accessoryRectangular])
    }
}
