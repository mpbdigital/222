import Foundation
import SwiftData
import WidgetKit

@MainActor
final class SharedComplicationDataManager {
    static let shared = SharedComplicationDataManager()
    

    let container: ModelContainer
    let context: ModelContext

    private init() {
        let schema = Schema([EventModel.self])
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.mpb.momenttimer") {
            print("[SharedComplicationDataManager] container path: \(url.path)")
            let storeURL = url.appendingPathComponent("Events.store")
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
        print("🔍 SharedComplicationDataManager.loadAllEvents — найдено \(models.count) записей")
        for model in models {
            print("    • \(model.name) [\(model.id)]")
        }
        return models.map { Event(from: $0) }
    }

    /// Удаляет все объекты `EventModel` из общего контейнера
    func deleteAllEvents() {
        let descriptor = FetchDescriptor<EventModel>()
        let models = (try? context.fetch(descriptor)) ?? []
        print("🗑 SharedComplicationDataManager.deleteAllEvents — удаляем \(models.count) записей")
        for model in models {
            context.delete(model)
        }
        do {
            try context.save()
            WidgetCenter.shared.reloadTimelines(ofKind: "EventComplication")
        } catch {
            print("❌ SharedComplicationDataManager: ошибка удаления — \(error)")
        }
    }
}
