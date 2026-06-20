# ArcadeCore

A reusable Swift package for shipping **hybrid-casual endless arcade games** on
iOS fast. Write the engine, monetization and UI **once**; each new game is just a
config + one scene subclass. GravityDash is the first game built on it.

## What's in the box (write once, reuse forever)
| Area | Type | What you get |
|------|------|--------------|
| Engine | `ScrollingGameScene` | run/phase state machine, delta-time loop, world-speed ramp, scoring, coin banking, camera screen-shake, death→**revive(ad)**→retry(**interstitial**)→**double-coins(ad)** flow, SwiftUI bridge |
| Bridge | `GameModel` | live phase/score/coins for SwiftUI; command closures the scene wires |
| Persistence | `GameStorage` | best score, coins, unlocked/selected skins, remove-ads, sound/haptics — namespaced per game |
| Monetization | `AdsProviding` + `StubAdsProvider`; `StoreManager` (StoreKit 2) | swappable ad network; rewarded/interstitial; IAP + restore |
| AdMob | `ArcadeCoreAdMob.AdMobAdsProvider` | rewarded + interstitial + ATT (optional product) |
| Feel | `Juice` | screen shake, particle bursts, pop/vanish (no assets needed) |
| Audio/Haptics | `AudioManager`, `Haptics` | bundle SFX (graceful no-op if missing), feedback |
| UI | `GameContainerView`, `MainMenuView`, `HUDView`, `PauseView`, `GameOverView`, `ShopView` | full menu/HUD/shop shell, themed by `GameConfig` |
| Theming | `GameConfig`, `Skin`, `RGBA` | palette, tuning, cosmetics, product/ad ids |

`ArcadeCore` has **no third-party dependencies** (always builds). AdMob lives in
the separate `ArcadeCoreAdMob` product so games without ads stay lean.

## Make a new game in 3 steps
1. **New iOS app** (XcodeGen `project.yml`) that depends on `ArcadeCore`
   (+ `ArcadeCoreAdMob` to monetize). Copy GravityDash's `project.yml`.
2. **Subclass `ScrollingGameScene`** and fill the hooks for your mechanic:
   `buildScene`, `layoutScene`, `resetRun`, `tick(dt:advance:)`, `onPlayTap`,
   `clearHazardsForRevive`, `handleContact`, and `autoPilot` (for `-autoplay`
   verification). See `GravityDash/Sources/Game/GameScene.swift` (~260 lines —
   that's the *whole* game-specific surface).
3. **Define a `GameConfig`** (name, palette, skins, product/ad ids) and wire the
   objects in a `GameHost` (copy `GravityDash/Sources/ContentView.swift`).

Everything else — menus, shop, ads, IAP, juice, persistence — is inherited.

## Built-in launch args (great for CI + App Preview capture)
- `-autoplay` — dodge AI plays the game (for screenshots/video without taps)
- `-demo` — attract mode: self-plays and cycles through game-over too
- `-stubads` — force the stub ad provider (no network, instant rewards)

## Reskin, don't rewrite
Same engine → new theme/skins/tuning = a new game in days. That's the strategy:
many small, cheap, polished games rather than one big bet.
