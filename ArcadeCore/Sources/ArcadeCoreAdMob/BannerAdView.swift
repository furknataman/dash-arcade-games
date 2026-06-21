import SwiftUI
import UIKit
import GoogleMobileAds

/// A SwiftUI adaptive AdMob banner. Drop it where a banner belongs (e.g. the
/// main menu). Sizes itself to the device width using an anchored adaptive
/// banner, so it looks right on every iPhone.
///
/// Ban safety: pass a TEST unit id in DEBUG/TestFlight and your real id only in
/// the public App Store build — the app decides which id to hand in.
public struct BannerAdView: View {
    private let adUnitID: String
    @State private var height: CGFloat = 60

    public init(adUnitID: String) {
        self.adUnitID = adUnitID
    }

    public var body: some View {
        _Banner(adUnitID: adUnitID, height: $height)
            .frame(height: height)
            .frame(maxWidth: .infinity)
    }
}

private struct _Banner: UIViewRepresentable {
    let adUnitID: String
    @Binding var height: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(height: $height) }

    func makeUIView(context: Context) -> GADBannerView {
        let banner = GADBannerView()
        banner.adUnitID = adUnitID
        banner.delegate = context.coordinator
        banner.rootViewController = AppPresenterUIKit.topViewController()
        loadAd(into: banner)
        return banner
    }

    func updateUIView(_ banner: GADBannerView, context: Context) {
        if banner.rootViewController == nil {
            banner.rootViewController = AppPresenterUIKit.topViewController()
        }
    }

    private func loadAd(into banner: GADBannerView) {
        let width = UIScreen.main.bounds.width
        banner.adSize = GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(width)
        banner.load(GADRequest())
    }

    final class Coordinator: NSObject, GADBannerViewDelegate {
        @Binding var height: CGFloat
        init(height: Binding<CGFloat>) { _height = height }

        func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
            let h = bannerView.adSize.size.height
            if h > 0 { height = h }
        }
    }
}

/// Local top-VC finder (AdMob target can't see ArcadeCore's AppPresenter).
enum AppPresenterUIKit {
    static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap { $0.windows }
        let key = windows.first { $0.isKeyWindow } ?? windows.first
        var top = key?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
