import SwiftData

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
