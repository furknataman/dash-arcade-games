import UIKit

/// Thin wrapper over UIFeedbackGenerator. Respects a global enabled flag that
/// the host app keeps in sync with `GameStorage.hapticsEnabled`.
public enum Haptics {
    public static var enabled = true

    public static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium,
                              intensity: CGFloat = 1.0) {
        guard enabled else { return }
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.prepare()
        gen.impactOccurred(intensity: intensity)
    }

    public static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    public static func selection() {
        guard enabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
