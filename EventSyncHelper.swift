import Foundation
import UserNotifications

struct EventSyncHelper {
    static func dictionary(from event: Event) -> [String: Any] {
        event.toDictionary()
    }

    static func shouldApplyUpdate(local: Event?, incoming: Date) -> Bool {
        guard let local = local else { return true }
        return incoming > local.lastModified
    }
}
