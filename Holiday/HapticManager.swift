import Foundation
import UIKit

class HapticManager {
    static let shared = HapticManager()

    /// Генерация тактильного отклика при помощи UIImpactFeedbackGenerator
    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard EventManager.shared.settings?.isHapticEnabled ?? true else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Генерация уведомительного отклика (success, warning, error)
    func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        guard EventManager.shared.settings?.isHapticEnabled ?? true else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}
