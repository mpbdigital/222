import WatchKit
import WatchConnectivity
import WidgetKit

class ExtensionDelegate: NSObject, WKExtensionDelegate, WCSessionDelegate {
    func applicationDidFinishLaunching() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("Ошибка активации WCSession: \(error.localizedDescription)")
        } else {
            print("WCSession активирована: \(activationState.rawValue)")
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        if let rawEvents = userInfo["events"] as? [[String: Any]] {
            let events = parseEvents(from: rawEvents)
            WatchDataManager.shared.save(events: events)
            WidgetCenter.shared.reloadAllTimelines()
            print("🔄 reloadAllTimelines() после получения UserInfo")
            WidgetCenter.shared.reloadTimelines(ofKind: "EventComplication")
            print("🔄 reloadTimelines(ofKind:) выполнен")
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        if let rawEvents = applicationContext["events"] as? [[String: Any]] {
            let events = parseEvents(from: rawEvents)
            WatchDataManager.shared.save(events: events)
            WidgetCenter.shared.reloadAllTimelines()
            print("🔄 reloadAllTimelines() после получения ApplicationContext")
            WidgetCenter.shared.reloadTimelines(ofKind: "EventComplication")
            print("🔄 reloadTimelines(ofKind:) выполнен")
        }
    }

    private func parseEvents(from rawEvents: [[String: Any]]) -> [Event] {
        return rawEvents.compactMap { dict in
            guard
                let idString = dict["id"] as? String,
                let id = UUID(uuidString: idString),
                let name = dict["name"] as? String,
                let dateTimestamp = dict["date"] as? TimeInterval,
                let typeRaw = dict["eventType"] as? String,
                let eventType = EventType(rawValue: typeRaw),
                let emoji = dict["emoji"] as? String,
                let showCountdown = dict["showCountdown"] as? Bool,
                let repeatYearly = dict["repeatYearly"] as? Bool
            else { return nil }

            let notificationTime: Date? = {
                if let nt = dict["notificationTime"] as? TimeInterval {
                    return Date(timeIntervalSince1970: nt)
                }
                return nil
            }()

            let isFromWatch = dict["isFromWatch"] as? Bool ?? false
            let isNewlyCreated = dict["isNewlyCreated"] as? Bool ?? false

            var event = Event(
                id: id,
                name: name,
                date: Date(timeIntervalSince1970: dateTimestamp),
                eventType: eventType,
                emoji: emoji,
                showCountdown: showCountdown,
                repeatYearly: repeatYearly,
                notificationTime: notificationTime,
                isFromWatch: isFromWatch
            )

            event.isNewlyCreated = isNewlyCreated

            return event
        }
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            if let appTask = task as? WKApplicationRefreshBackgroundTask {
                // работаем с накопленными данными
                appTask.setTaskCompletedWithSnapshot(false)
            } else {
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }
}
