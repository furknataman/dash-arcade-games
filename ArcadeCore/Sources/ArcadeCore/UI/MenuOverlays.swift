import SwiftUI

// MARK: - Main menu (phase: .ready)
public struct MainMenuView: View {
    @ObservedObject var model: GameModel
    @ObservedObject var storage: GameStorage
    @ObservedObject var gameCenter = GameCenter.shared
    let config: GameConfig
    var banner: AnyView? = nil
    @State private var pulse = false

    public var body: some View {
        ZStack {
            Color(config.background).opacity(0.78).ignoresSafeArea()
            VStack(spacing: 18) {
                Spacer()

                VStack(spacing: 6) {
                    Text(config.displayName.uppercased())
                        .font(.system(size: 46, weight: .black, design: .rounded))
                        .foregroundStyle(Color(config.accent))
                        .shadow(color: Color(config.accent).opacity(0.55), radius: 14)
                        .multilineTextAlignment(.center)
                    Text(LocalizedStringKey(config.tagline))
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .tracking(3)
                        .foregroundStyle(.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 12) {
                    StatChip(icon: "🏆", text: "\(storage.bestScore)")
                    StatChip(icon: "🪙", text: "\(storage.coins)", tint: Color(config.coin))
                }

                Spacer()

                VStack(spacing: 12) {
                    Button("PLAY") { model.startTapped() }
                        .buttonStyle(ArcadeButtonStyle(fill: Color(config.accent),
                                                       foreground: Color(config.background)))
                        .scaleEffect(pulse ? 1.03 : 1.0)

                    HStack(spacing: 12) {
                        Button { model.showShop = true } label: {
                            Label("SHOP", systemImage: "bag.fill")
                        }
                        .buttonStyle(ArcadeButtonStyle(fill: .white.opacity(0.14), prominent: false))

                        Button { gameCenter.openLeaderboard() } label: {
                            Label("RANKS", systemImage: "trophy.fill")
                        }
                        .buttonStyle(ArcadeButtonStyle(fill: .white.opacity(0.14), prominent: false))
                    }

                    if !storage.removeAdsPurchased {
                        Button { model.showShop = true } label: {
                            Label("Remove Ads", systemImage: "nosign")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.top, 2)
                    }
                }
                .padding(.horizontal, 40)

                HStack(spacing: 26) {
                    Toggle("", isOn: $storage.soundEnabled).labelsHidden()
                        .toggleStyle(IconToggleStyle(on: "🔊", off: "🔇"))
                    Toggle("", isOn: $storage.hapticsEnabled).labelsHidden()
                        .toggleStyle(IconToggleStyle(on: "📳", off: "🚫"))
                }
                .padding(.top, 4)

                Spacer()

                // Banner ad lives only here (home screen), never during play.
                if let banner {
                    banner.frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.95).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .alert("Sign in to Game Center to see the leaderboard.",
               isPresented: $gameCenter.needsSignIn) {
            Button("OK", role: .cancel) {}
        }
    }
}

// MARK: - In-game HUD (phase: .playing). Only the top bar is interactive so
// taps in the play area pass through to the scene.
public struct HUDView: View {
    @ObservedObject var model: GameModel
    let config: GameConfig

    public var body: some View {
        VStack {
            HStack {
                StatChip(icon: "🪙", text: "\(model.runCoins)", tint: Color(config.coin))
                Spacer()
                Text("\(model.score)")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(model.scoreTint.map { Color($0) } ?? .white)
                    .shadow(radius: 6)
                    .animation(.easeInOut(duration: 0.3), value: model.scoreTint)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: model.score)
                Spacer()
                Button { model.pauseTapped() } label: {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(Circle().fill(.black.opacity(0.28)))
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            Spacer()
        }
    }
}

// MARK: - Pause (phase: .paused)
public struct PauseView: View {
    @ObservedObject var model: GameModel
    let config: GameConfig

    public var body: some View {
        ZStack {
            Color(config.background).opacity(0.8).ignoresSafeArea()
            VStack(spacing: 18) {
                Text("PAUSED").font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Button("RESUME") { model.resumeTapped() }
                    .buttonStyle(ArcadeButtonStyle(fill: Color(config.accent),
                                                   foreground: Color(config.background)))
                Button("HOME") { model.homeTapped() }
                    .buttonStyle(ArcadeButtonStyle(fill: .white.opacity(0.16), prominent: false))
            }
            .padding(.horizontal, 56)
        }
    }
}

// MARK: - Game over (phase: .dead)
public struct GameOverView: View {
    @ObservedObject var model: GameModel
    @ObservedObject var gameCenter = GameCenter.shared
    let config: GameConfig

    public var body: some View {
        ZStack {
            Color(config.background).opacity(0.86).ignoresSafeArea()
            VStack(spacing: 18) {
                Spacer()
                Text(model.newBest ? "NEW BEST!" : "GAME OVER")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(model.newBest ? Color(config.coin) : .white)
                    .shadow(color: model.newBest ? Color(config.coin).opacity(0.6) : .clear, radius: 14)

                HStack(spacing: 12) {
                    StatChip(icon: "⭐️", text: "\(model.score)")
                    StatChip(icon: "🏆", text: "\(model.bestScore)")
                    StatChip(icon: "🪙", text: "\(model.runCoins)\(model.coinsDoubled ? " ×2" : "")",
                             tint: Color(config.coin))
                }

                Spacer()

                VStack(spacing: 12) {
                    if model.canRevive {
                        Button { model.reviveTapped() } label: {
                            Label("REVIVE", systemImage: "play.rectangle.fill")
                        }
                        .buttonStyle(ArcadeButtonStyle(fill: Color(config.accent),
                                                       foreground: Color(config.background)))
                    }
                    if !model.coinsDoubled && model.runCoins > 0 {
                        Button { model.doubleCoinsTapped() } label: {
                            Label("DOUBLE COINS", systemImage: "play.rectangle.fill")
                        }
                        .buttonStyle(ArcadeButtonStyle(fill: Color(config.coin),
                                                       foreground: Color(config.background)))
                    }
                    Button("RETRY") { model.restartTapped() }
                        .buttonStyle(ArcadeButtonStyle(fill: .white.opacity(0.18), prominent: false))
                    HStack(spacing: 12) {
                        Button("HOME") { model.homeTapped() }
                            .buttonStyle(ArcadeButtonStyle(fill: .white.opacity(0.10), prominent: false))
                        Button { gameCenter.openLeaderboard() } label: {
                            Label("RANKS", systemImage: "trophy.fill")
                        }
                        .buttonStyle(ArcadeButtonStyle(fill: .white.opacity(0.10), prominent: false))
                    }
                }
                .padding(.horizontal, 44)
                Spacer()
            }
            .padding()
        }
        .alert("Sign in to Game Center to see the leaderboard.",
               isPresented: $gameCenter.needsSignIn) {
            Button("OK", role: .cancel) {}
        }
    }
}

// MARK: - Small toggle rendered as an emoji icon.
struct IconToggleStyle: ToggleStyle {
    let on: String
    let off: String
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            Text(configuration.isOn ? on : off)
                .font(.system(size: 24))
                .opacity(configuration.isOn ? 1 : 0.5)
        }
        .buttonStyle(.plain)
    }
}
