# Shipping GravityDash

The app is **archive-ready and signed** (`build/GravityDash.xcarchive` built with
your team `PY8XQ9L8AA`). What remains is account setup only — code is done.

## Before public release (do these first)
1. **Real AdMob ids.** The app ships with Google **TEST** ids so it's playable
   now. Replace before release:
   - `GravityDash-Info.plist` → `GADApplicationIdentifier` (your AdMob App ID)
   - `Sources/ContentView.swift` → `GameConfig(... rewardedAdUnitID, interstitialAdUnitID ...)`
     (currently the defaults in `ArcadeCore/GameConfig.swift`)
   TestFlight builds can keep the test ids; only the public release needs real ones.
2. **App Store Connect record.** Create an app with bundle id
   `com.solvy.gravitydash`, plus the IAP `com.solvy.gravitydash.removeads`
   (Non-Consumable, ~$2.99). Copy listing text from `AppStore/metadata.md`.
3. **Screenshots.** `AppStore/screenshots/` has 6.9" menu + gameplay (1320×2868).
   Capture more with: launch any sim with `-demo` (attract mode) or `-autoplay`
   and `xcrun simctl io <udid> screenshot`.

## Game Center (leaderboard)
The app authenticates the player and submits the best score to leaderboard id
**`gravitydash.high_score`**. To make it live:
1. App Store Connect → your app → **Features ▸ Game Center** → add a
   **Leaderboard** with id `gravitydash.high_score` (Integer, High to Low).
2. The **Game Center** capability is already declared in `GravityDash.entitlements`;
   automatic signing enables it on the App ID.
3. Test with a **Game Center Sandbox** account (Settings ▸ Game Center on the
   device/simulator). Until the leaderboard exists in ASC, the in-app "RANKS"
   button still opens Game Center but shows no entries.

## Upload (one of)
- **Easiest:** run the `appstore-ship` skill in this folder (archive + export +
  upload via your App Store Connect API key — `.p8` + key id + issuer id).
- **Manual:** open `GravityDash.xcodeproj` in Xcode → Product ▸ Archive ▸
  Distribute App ▸ App Store Connect.
- **CLI:** the signed archive already exists; export with an
  `ExportOptions.plist` (`method: app-store`) then `xcrun altool`/`notarytool`
  or Transporter.

## Privacy answers (App Store Connect questionnaire)
- Data used to **track** you: *Yes* (AdMob — Identifiers / Usage Data for ads).
- The app's own code only reads `UserDefaults` (declared in `PrivacyInfo.xcprivacy`).
- ATT prompt is implemented; encryption: exempt (`ITSAppUsesNonExemptEncryption=false`).

## Verify on a device first
TestFlight build → check ATT prompt, a rewarded ad (revive / double coins),
an interstitial, and the Remove-Ads purchase + Restore.
