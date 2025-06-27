import WidgetKit
import SwiftUI
import SwiftData
import AppIntents

@Model
class SettingsModel {
    @Attribute(.unique) var id: Int
    var pro: Bool
    var isFirstLaunch: Bool
    var isOnboardingCompleted: Bool
    var migrationCompleted: Bool
    var enableRecurringEvents: Bool
    var isHapticEnabled: Bool

    init(id: Int = 0,
         pro: Bool = false,
         isFirstLaunch: Bool = true,
         isOnboardingCompleted: Bool = false,
         migrationCompleted: Bool = false,
         enableRecurringEvents: Bool = false,
         isHapticEnabled: Bool = true) {
        self.id = id
        self.pro = pro
        self.isFirstLaunch = isFirstLaunch
        self.isOnboardingCompleted = isOnboardingCompleted
        self.migrationCompleted = migrationCompleted
        self.enableRecurringEvents = enableRecurringEvents
        self.isHapticEnabled = isHapticEnabled
    }
}

enum EventType: String, Codable, CaseIterable {
    case event
    case birthday

    var localizedName: String {
        switch self {
        case .event:
            return NSLocalizedString("event_type_event", comment: "")
        case .birthday:
            return NSLocalizedString("event_type_birthday", comment: "")
        }
    }
}

struct ChecklistItem: Identifiable, Codable {
    let id: UUID
    let text: String
    var isCompleted: Bool
}

struct Event: Identifiable, Codable {
    let id: UUID
    let name: String
    let date: Date
    let emoji: String
    var isPinned: Bool = false
    var originalIndex: Int? = nil
    var note: String?
    var checklist: [ChecklistItem] = []
    var eventType: EventType
    
    var age: Int? {
        if case .birthday = eventType {
            let calendar = Calendar.current
            let now = Date()
            let components = calendar.dateComponents([.year], from: date, to: now)
            return components.year
        }
        return nil
    }
    
    var isToday: Bool {
        let calendar = Calendar.current
        return calendar.isDateInToday(date)
    }
    
    var hasTime: Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour != 0 || components.minute != 0)
    }
}

// MARK: - Shared Types for SwiftData

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

extension ChecklistItem {
    init(from model: ChecklistItemModel) {
        self.id = model.id
        self.text = model.text
        self.isCompleted = model.isCompleted
    }
}

extension Event {
    init(from model: EventModel) {
        self.id = model.id
        self.name = model.name
        self.date = model.date
        self.emoji = model.emoji
        self.isPinned = model.isPinned
        self.originalIndex = model.originalIndex
        self.note = model.note
        self.checklist = Array(model.checklist)
            .sorted(by: { $0.order < $1.order })
            .map { ChecklistItem(from: $0) }
        self.eventType = model.eventType
    }
}

struct EventWidgetProvider: TimelineProvider {
    typealias Entry = EventEntry

    private let modelContext: ModelContext

    static let sharedContainer: ModelContainer = {
        let schema = Schema([EventModel.self, ChecklistItemModel.self, SettingsModel.self])
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.mpb.momenttimer") else {
            print("⚠️ Failed to locate app group container. Using default location.")
            if let container = try? ModelContainer(for: schema) {
                return container
            }
            fatalError("Unable to create SwiftData container")
        }
        print("[HolidayWidget] container path: \(url.path)")
        let storeURL = url.appendingPathComponent("Events.store")
        let configuration = ModelConfiguration(schema: schema, url: storeURL)
        if let container = try? ModelContainer(for: schema, configurations: [configuration]) {
            return container
        } else {
            print("⚠️ Failed to load SwiftData container in widget. Using default.")
            if let fallback = try? ModelContainer(for: schema) {
                return fallback
            }
            fatalError("Unable to create SwiftData container")
        }
    }()

    @MainActor init() {
        self.modelContext = Self.sharedContainer.mainContext
    }

    let sampleEvent1 = Event(
        id: UUID(),
        name: NSLocalizedString("SAMPLE_EVENT_MEET_FRIENDS", comment: ""),
        date: Date().addingTimeInterval(3600 * 24),
        emoji: "🍕",
        isPinned: true,
        checklist: [
            ChecklistItem(
                id: UUID(),
                text: NSLocalizedString("SAMPLE_EVENT_CHECK_PIZZA", comment: ""),
                isCompleted: false
            ),
            ChecklistItem(
                id: UUID(),
                text: NSLocalizedString("SAMPLE_EVENT_CHECK_CALL_FRIENDS", comment: ""),
                isCompleted: true
            )
        ],
        eventType: .event
    )

    let sampleEvent2 = Event(
        id: UUID(),
        name: NSLocalizedString("SAMPLE_EVENT_ANNA_BIRTHDAY", comment: ""),
        date: Calendar.current.date(byAdding: .day, value: 2, to: Date())!,
        emoji: "🎂",
        isPinned: true,
        note: NSLocalizedString("SAMPLE_EVENT_ANNA_NOTE", comment: ""),
        checklist: [
            ChecklistItem(
                id: UUID(),
                text: NSLocalizedString("SAMPLE_EVENT_CHECK_CHOOSE_GIFT", comment: ""),
                isCompleted: false
            )
        ],
        eventType: .birthday
    )

    let sampleEvent3 = Event(
        id: UUID(),
        name: NSLocalizedString("SAMPLE_EVENT_WORK_MEETING", comment: ""),
        date: Calendar.current.date(byAdding: .day, value: 5, to: Date())!,
        emoji: "📅",
        isPinned: false,
        checklist: [],
        eventType: .event
    )

    func placeholder(in context: Context) -> EventEntry {
        EventEntry(date: Date(), events: [sampleEvent1, sampleEvent2, sampleEvent3])
    }

    func getSnapshot(in context: Context, completion: @escaping (EventEntry) -> ()) {
        let picnicEvent = Event(
            id: UUID(),
            name: NSLocalizedString("SAMPLE_EVENT_PICNIC", comment: ""),
            date: Date().addingTimeInterval(3600 * 24 * 3),
            emoji: "🌳",
            isPinned: false,
            checklist: [
                ChecklistItem(
                    id: UUID(),
                    text: NSLocalizedString("SAMPLE_EVENT_CHECK_BRING_FOOD", comment: ""),
                    isCompleted: false
                ),
                ChecklistItem(
                    id: UUID(),
                    text: NSLocalizedString("SAMPLE_EVENT_CHECK_SETUP_GAMES", comment: ""),
                    isCompleted: true
                )
            ],
            eventType: .event
        )
        
        let birthdayEvent = Event(
            id: UUID(),
            name: NSLocalizedString("SAMPLE_EVENT_ELON_NAME", comment: ""),
            date: Calendar.current.date(from: DateComponents(year: 1971, month: 6, day: 28))!,
            emoji: "🎂",
            isPinned: true,
            note: NSLocalizedString("SAMPLE_EVENT_ELON_NOTE", comment: ""),
            checklist: [
                ChecklistItem(
                    id: UUID(),
                    text: NSLocalizedString("SAMPLE_EVENT_ELON_CHECK_CALL", comment: ""),
                    isCompleted: false
                )
            ],
            eventType: .birthday
        )

        let sampleEvent3 = Event(
            id: UUID(),
            name: NSLocalizedString("SAMPLE_EVENT_ANNA_BIRTHDAY", comment: ""),
            date: Calendar.current.date(byAdding: .day, value: 2, to: Date())!,
            emoji: "🎂",
            isPinned: true,
            checklist: [
                ChecklistItem(
                    id: UUID(),
                    text: NSLocalizedString("SAMPLE_EVENT_CHECK_PREPARE_GIFT", comment: ""),
                    isCompleted: false
                )
            ],
            eventType: .birthday
        )

        let entry = EventEntry(date: Date(), events: [picnicEvent, birthdayEvent, sampleEvent3])
        print("📦 getSnapshot: отправляем события в completion: \(entry.events.map { $0.name }.joined(separator: ", "))")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EventEntry>) -> ()) {
        let descriptor = FetchDescriptor<EventModel>()
        let models = (try? modelContext.fetch(descriptor)) ?? []
        let allEvents = models.map(Event.init)
        let events = allEvents.filter { $0.eventType == .event }
        let birthdays = allEvents.filter { $0.eventType == .birthday }
        
        let now = Date()
        let futureEvents = events.filter { $0.date >= now }

        let eventsWithNextDate = (futureEvents + birthdays).map { event -> (Event, Date) in
            (event, nextOccurrenceDate(for: event))
        }
        let sortedFutureEvents = eventsWithNextDate.sorted { $0.1 < $1.1 }.map { $0.0 }

        let entries: [EventEntry]
        if sortedFutureEvents.isEmpty {
            let emptyEntry = EventEntry(date: Date(), events: [])
            entries = [emptyEntry]
        } else {
            entries = [EventEntry(date: Date(), events: sortedFutureEvents)]
        }

        let timeline = Timeline(entries: entries, policy: .after(Date().addingTimeInterval(60 * 5)))
        let eventNames = entries.flatMap { $0.events.map { $0.name } }.joined(separator: ", ")
        print("📦 getTimeline: отправляем события в completion: \(eventNames)")
        completion(timeline)
    }

    private func nextOccurrenceDate(for event: Event) -> Date {
        let calendar = Calendar.current
        let now = Date()

        if event.eventType == .birthday {
            let comp = calendar.dateComponents([.month, .day], from: event.date)
            var next = calendar.date(from: DateComponents(year: calendar.component(.year, from: now), month: comp.month, day: comp.day))!
            if next < now {
                next = calendar.date(byAdding: .year, value: 1, to: next)!
            }
            return next
        }

        return event.date
    }
}

struct EventEntry: TimelineEntry {
    let date: Date
    let events: [Event]
}

struct EventWidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    @Environment(\.colorScheme) var colorScheme
    
    var entry: EventEntry

    private func isTodayBirthday(eventDate: Date) -> Bool {
        let calendar = Calendar.current
        let todayComponents = calendar.dateComponents([.month, .day], from: Date())
        let eventComponents = calendar.dateComponents([.month, .day], from: eventDate)
        return (todayComponents.month == eventComponents.month
                && todayComponents.day == eventComponents.day)
    }

    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            smallWidgetView()
        case .systemMedium:
            mediumWidgetView()
        case .systemLarge:
            largeWidgetView()
        default:
            mediumWidgetView()
        }
    }

    private func smallWidgetView() -> some View {
        VStack(spacing: 8) {
            if entry.events.isEmpty {
                VStack {
                    Spacer()
                    AddEventButton()
                    Text(NSLocalizedString("WIDGET_ADD_EVENT", comment: ""))
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                        .bold()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                if let event = entry.events.first {
                    if event.eventType == .event && !event.isToday && event.date < Date() {
                        EmptyView()
                    } else {
                        VStack(spacing: 4) {
                            Text(event.emoji)
                                .font(.system(size: 35))
                                .foregroundColor(.blue)
                            Text(event.name)
                                .font(.subheadline)
                                .lineLimit(2)
                                .truncationMode(.tail)
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                                .fixedSize(horizontal: false, vertical: true)
                            if event.eventType == .birthday, let age = event.age {
                                let calendar = Calendar.current
                                let now = Date()
                                let eventComponents = calendar.dateComponents([.month, .day], from: event.date)
                                let currentComponents = calendar.dateComponents([.month, .day], from: now)
                                if isTodayBirthday(eventDate: event.date) {
                                    Text(String(format: NSLocalizedString("event.age_prefix", comment: ""), age))
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .padding(.top, -3)
                                    
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
                                    Text(String(format: NSLocalizedString("event.age_prefix", comment: ""), age))
                                        .font(.caption)
                                }
                            }
                        }
                    }
                    if let event = entry.events.first {
                        if let futureDate = getFutureDate(for: event.date, event: event) {
                            Text(futureDate, style: .relative)
                                .frame(width: 130, height: 20)
                                .monospacedDigit()
                                .multilineTextAlignment(.center)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .font(.footnote)
                                .padding(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
                                .background(Color.blue.opacity(0.8))
                                .cornerRadius(8)
                        }
                        
                        VStack(spacing: 2) {
                            let calendar = Calendar.current
                            Text("\(event.date, formatter: dateFormatter)")
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            if event.hasTime && event.eventType != .birthday {
                                Text("\(event.date, formatter: timeFormatter)")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            else if event.eventType == .birthday, let age = event.age,
                                    !(event.isToday && calendar.isDateInToday(event.date)) {
                                Text(String(format: NSLocalizedString("event.age_prefix", comment: ""), age))
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                        .lineLimit(1)
                        .truncationMode(.tail)
                    }
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }

    private func mediumWidgetView() -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            if entry.events.isEmpty {
                VStack {
                    Spacer()
                    AddEventButton()
                    Text(NSLocalizedString("WIDGET_ADD_EVENT", comment: ""))
                        .font(.caption)
                        .foregroundColor(.gray)
                        .bold()
                }
            } else {
                ForEach(entry.events.prefix(2)) { event in
                    HStack {
                        Text(event.emoji)
                            .font(.largeTitle)
                        VStack(alignment: .leading) {
                            Text(event.name)
                                .font(.subheadline)
                                .padding(EdgeInsets(top: 6, leading: 0, bottom: 1, trailing: 2))
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(event.date, formatter: dateFormatter)")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                    
                                    if event.eventType == .birthday, let age = event.age {
                                        Text(String(format: NSLocalizedString("event.age_prefix", comment: ""), age))
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                    else if event.hasTime {
                                        Text("\(event.date, formatter: timeFormatter)")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding(EdgeInsets(top: 0, leading: 4, bottom: 1, trailing: 4))
                                
                                Spacer()
                                
                                if let futureDate = getFutureDate(for: event.date, event: event) {
                                    Text(futureDate, style: .relative)
                                        .frame(width: 130, height: 20)
                                        .monospacedDigit()
                                        .multilineTextAlignment(.center)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .font(.footnote)
                                        .padding(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
                                        .background(Color.blue.opacity(0.8))
                                        .cornerRadius(8)
                                } else if event.eventType == .birthday && isTodayBirthday(eventDate: event.date) {
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
                                    if event.isToday {
                                        Text(NSLocalizedString("WIDGET_EVENT_TODAY", comment: ""))
                                            .font(.subheadline)
                                    } else {
                                        Text(NSLocalizedString("WIDGET_EVENT_PASSED", comment: ""))
                                            .font(.subheadline)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(EdgeInsets(top: 4, leading: 8, bottom: 6, trailing: 8))
                    .background(conditionalColor)
                    .cornerRadius(8)
                }
            }
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }

    private let maxChecklistItemsShown = 3

    private func largeWidgetView() -> some View {
        GeometryReader { geometry in
            let availableHeight = geometry.size.height
            let displayedEvents = eventsThatFit(availableHeight: availableHeight)

            VStack(alignment: .trailing, spacing: 8) {
                if displayedEvents.isEmpty {
                    VStack {
                        Spacer()
                        AddEventButton()
                        Text(NSLocalizedString("WIDGET_ADD_EVENT", comment: ""))
                            .font(.caption)
                            .foregroundColor(.gray)
                            .bold()
                    }
                } else {
                    ForEach(displayedEvents) { event in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(event.emoji)
                                    .font(.largeTitle)
                                VStack(alignment: .leading) {
                                    Text(event.name)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                    HStack(spacing: 8) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("\(event.date, formatter: dateFormatter)")
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.7)

                                            if event.eventType == .birthday, let age = event.age {
                                                Text(String(format: NSLocalizedString("event.age_prefix", comment: ""), age))
                                                    .font(.caption2)
                                                    .foregroundColor(.gray)
                                            } else if event.hasTime {
                                                Text("\(event.date, formatter: timeFormatter)")
                                                    .font(.caption2)
                                                    .foregroundColor(.gray)
                                            }
                                        }

                                        Spacer()

                                        if let futureDate = getFutureDate(for: event.date, event: event) {
                                            Text(futureDate, style: .relative)
                                                .frame(width: 130, height: 20)
                                                .monospacedDigit()
                                                .multilineTextAlignment(.center)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                                .font(.footnote)
                                                .padding(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
                                                .background(Color.blue.opacity(0.8))
                                                .cornerRadius(8)
                                        } else if event.eventType == .birthday && isTodayBirthday(eventDate: event.date) {
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
                                        }
                                    }
                                }
                            }
                            .padding(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                            .background(conditionalColor)
                            .cornerRadius(8)

                            if let note = event.note, !note.isEmpty {
                                Text(note)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding(.leading, 8)
                                    .padding(.top, 4)
                            }

                            if !event.checklist.isEmpty {
                                let ordered = event.checklist
                                VStack(alignment: .leading, spacing: 2) {
                                    ForEach(Array(ordered.prefix(maxChecklistItemsShown))) { item in
                                        Button(intent: ToggleChecklistIntent(eventId: event.id.uuidString, itemId: item.id.uuidString)) {
                                            HStack {
                                                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                                    .foregroundColor(item.isCompleted ? .green : .gray)
                                                Text(item.text)
                                                    .font(.caption2)
                                                    .strikethrough(item.isCompleted)
                                                    .foregroundColor(item.isCompleted ? .gray : .primary)
                                            }
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    if ordered.count > maxChecklistItemsShown {
                                        Text("… +\(ordered.count - maxChecklistItemsShown)")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                            .padding(.leading, 4)
                                    }
                                }
                                .padding(.leading, 16)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .containerBackground(for: .widget) {
                Color(.systemBackground)
            }
        }
    }

    var conditionalColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.2) : Color.black.opacity(0.04)
    }

    private func estimatedHeight(for event: Event) -> CGFloat {
        var height: CGFloat = 85
        if let note = event.note, !note.isEmpty {
            height += 20
        }
        if !event.checklist.isEmpty {
            let itemsToShow = min(event.checklist.count, maxChecklistItemsShown)
            height += CGFloat(itemsToShow) * 20
            if event.checklist.count > maxChecklistItemsShown {
                height += 16
            }
        }
        return height
    }

    private func eventsThatFit(availableHeight: CGFloat) -> [Event] {
        var used: CGFloat = 0
        var result: [Event] = []
        for event in entry.events {
            let h = estimatedHeight(for: event)
            if used + h <= availableHeight {
                result.append(event)
                used += h
            } else {
                break
            }
        }
        return result
    }

    private func getFutureDate(for eventDate: Date, event: Event) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        
        if event.eventType == .birthday && isTodayBirthday(eventDate: eventDate) {
            return nil
        }
        
        if event.eventType == .birthday {
            let eventMonthDay = calendar.dateComponents([.month, .day], from: eventDate)
            let currentMonthDay = calendar.dateComponents([.month, .day], from: now)
            
            var futureDateComponents = DateComponents(
                year: calendar.component(.year, from: now),
                month: eventMonthDay.month,
                day: eventMonthDay.day
            )
            
            if currentMonthDay.month! > eventMonthDay.month! ||
                (currentMonthDay.month == eventMonthDay.month && currentMonthDay.day! >= eventMonthDay.day!) {
                futureDateComponents.year! += 1
            }
            
            return calendar.date(from: futureDateComponents)
        } else {
            if eventDate < now, !calendar.isDateInToday(eventDate) {
                return nil
            }
            return eventDate
        }
    }
}

struct ToggleChecklistIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Checklist Item"
    static var description = IntentDescription("Toggles the completion state of a checklist item.")
    
    @Parameter(title: "Event ID")
    var eventId: String
    
    @Parameter(title: "Checklist Item ID")
    var itemId: String
    
    init() {}
    
    init(eventId: String, itemId: String) {
        self.eventId = eventId
        self.itemId = itemId
    }
    
    func perform() async throws -> some IntentResult {
        guard let eventUUID = UUID(uuidString: eventId),
              let itemUUID = UUID(uuidString: itemId) else {
            return .result()
        }
        
        let container = EventWidgetProvider.sharedContainer
        let context = await container.mainContext
        
        let descriptor = FetchDescriptor<EventModel>(predicate: #Predicate { $0.id == eventUUID })
        if let event = try? context.fetch(descriptor).first,
           let item = event.checklist.first(where: { $0.id == itemUUID }) {
            item.toggleCompletion()
            try? context.save()
            
            WidgetCenter.shared.reloadTimelines(ofKind: "EventWidget")
        }
        
        return .result()
    }
}

struct AddEventButton: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .foregroundColor(.blue)
                .frame(width: 60, height: 60)
                .shadow(color: .gray, radius: 3, x: 0, y: 2)
            Image(systemName: "plus")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 30, height: 30)
                .foregroundColor(.white)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

func getYearsWord(_ count: Int) -> String {
    let countMod10 = count % 10
    let countMod100 = count % 100
    
    if countMod10 == 1 && countMod100 != 11 {
        return "год"
    } else if countMod10 >= 2 && countMod10 <= 4 && (countMod100 < 10 || countMod100 >= 20) {
        return "года"
    } else {
        return "лет"
    }
}

@main
struct EventWidget: Widget {
    let kind: String = "EventWidget"

    var body: some WidgetConfiguration {
        if #available(iOS 17.0, *) {
            return StaticConfiguration(kind: kind, provider: EventWidgetProvider()) { entry in
                EventWidgetEntryView(entry: entry)
            }
            .configurationDisplayName(NSLocalizedString("WIDGET_DISPLAY_NAME", comment: ""))
            .description(NSLocalizedString("WIDGET_DISPLAY_DESCRIPTION", comment: ""))
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        } else {
            return StaticConfiguration(kind: kind, provider: EventWidgetProvider()) { entry in
                EventWidgetEntryView(entry: entry)
            }
            .configurationDisplayName(NSLocalizedString("WIDGET_DISPLAY_NAME", comment: ""))
            .description(NSLocalizedString("WIDGET_DISPLAY_DESCRIPTION", comment: ""))
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        }
    }
}

let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
}()

let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    return formatter
}()
