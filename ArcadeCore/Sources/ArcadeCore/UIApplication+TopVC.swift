import UIKit

/// Finds the frontmost view controller to present system UI (Game Center, etc.)
/// from SwiftUI/SpriteKit contexts.
public enum AppPresenter {
    public static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap { $0.windows }
        let key = windows.first { $0.isKeyWindow } ?? windows.first
        var top = key?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }

    public static func present(_ vc: UIViewController) {
        topViewController()?.present(vc, animated: true)
    }
}
