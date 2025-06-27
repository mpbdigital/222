import Foundation
import SwiftData
import WidgetKit
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



extension Event {
    init(from model: EventModel) {
        self.id = model.id
        self.name = model.name
        self.date = model.date
        self.eventType = model.eventType
        self.emoji = model.emoji
        self.showCountdown = model.showCountdown
        self.notificationType = model.notificationType
        self.notificationEnabled = model.notificationEnabled
        self.repeatYearly = model.repeatYearly
        self.notificationTime = model.notificationTime
        self.bellActivated = model.bellActivated
        self.deletePastEvents = model.deletePastEvents
        self.isFromWatch = model.isFromWatch
        self.isNewlyCreated = model.isNewlyCreated
        self.lastModified = model.lastModified
    }
}

@MainActor
final class WatchDataManager {
    static let shared = WatchDataManager()

    let container: ModelContainer
    let context: ModelContext

    private init() {
        let schema = Schema([EventModel.self, ChecklistItemModel.self])
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.mpb.momenttimer") {
            print("[WatchDataManager] container path: \(groupURL.path)")
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

    func save(events: [Event]) {
        print("💾 WatchDataManager.save — получено \(events.count) событий")
        for event in events {
            print("    • \(event.name) [\(event.id)]")
        }
        // Получаем все существующие записи из базы
        let existingModels = (try? context.fetch(FetchDescriptor<EventModel>())) ?? []
        let incomingIds = Set(events.map { $0.id })

        // Удаляем устаревшие события
        for model in existingModels where !incomingIds.contains(model.id) {
            context.delete(model)
        }

        for event in events {
            let descriptor = FetchDescriptor<EventModel>(predicate: #Predicate { $0.id == event.id })
            if let model = try? context.fetch(descriptor).first {
                model.name = event.name
                model.date = event.date
                model.eventType = event.eventType
                model.emoji = event.emoji
                model.showCountdown = event.showCountdown
                model.notificationType = event.notificationType
                model.notificationEnabled = event.notificationEnabled
                model.repeatYearly = event.repeatYearly
                model.notificationTime = event.notificationTime
                model.bellActivated = event.notificationTime != nil
                model.deletePastEvents = event.deletePastEvents
                model.isFromWatch = event.isFromWatch
                model.isNewlyCreated = event.isNewlyCreated
                model.lastModified = event.lastModified
            } else {
                let model = EventModel(
                    id: event.id,
                    name: event.name,
                    date: event.date,
                    creationDate: Date(),
                    showCountdown: event.showCountdown,
                    eventType: event.eventType,
                    emoji: event.emoji,
                    notificationType: event.notificationType,
                    notificationEnabled: event.notificationEnabled,
                    notificationTime: event.notificationTime,
                    deletePastEvents: event.deletePastEvents,
                    lastModified: event.lastModified,
                    repeatYearly: event.repeatYearly,
                    bellActivated: event.notificationTime != nil,
                    isFromWatch: event.isFromWatch,
                    isNewlyCreated: event.isNewlyCreated
                )
                context.insert(model)
            }
        }
        do {
            try context.save()
            WidgetCenter.shared.reloadTimelines(ofKind: "EventComplication")
            print("✅ WatchDataManager: успешно сохранено \(events.count) событий")
        } catch {
            print("❌ WatchDataManager: ошибка сохранения — \(error)")
        }
    }

    func loadAllEvents() -> [Event] {
        let models = (try? context.fetch(FetchDescriptor<EventModel>())) ?? []
        print("🔍 WatchDataManager.loadAllEvents — найдено \(models.count) записей")
        for model in models {
            print("    • \(model.name) [\(model.id)]")
        }
        return models.map { Event(from: $0) }
    }
}

