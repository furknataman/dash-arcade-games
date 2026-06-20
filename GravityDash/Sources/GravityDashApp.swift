import SwiftUI
import AppTrackingTransparency
import ArcadeCoreAdMob

@main
struct GravityDashApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
                .task { await requestTrackingIfNeeded() }
        }
    }

    /// Show the ATT prompt shortly after launch (skipped in automated runs).
    private func requestTrackingIfNeeded() async {
        let stub = CommandLine.arguments.contains("-autoplay")
            || CommandLine.arguments.contains("-demo")
            || CommandLine.arguments.contains("-stubads")
            || CommandLine.arguments.contains("-adtest")
        guard !stub else { return }
        try? await Task.sleep(nanoseconds: 500_000_000)
        AdMobAdsProvider.requestTrackingThenStart()
    }
}
