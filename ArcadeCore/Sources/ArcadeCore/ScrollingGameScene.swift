import SpriteKit

/// Reusable base for endless side-scrolling arcade games.
///
/// It owns everything that is the SAME across games — the run/phase state
/// machine, delta-time loop, world-speed ramp, scoring, coin banking, screen
/// shake, the death → revive(ad) → retry(interstitial) → double-coins(ad) flow,
/// and the SwiftUI bridge. A concrete game subclasses it and fills the hooks:
/// `buildScene`, `layoutScene`, `resetRun`, `tick`, `onPlayTap`,
/// `clearHazardsForRevive`, and `handleContact`.
open class ScrollingGameScene: SKScene, SKPhysicsContactDelegate {

    // Injected dependencies
    public let config: GameConfig
    public weak var model: GameModel?
    public let storage: GameStorage
    public var ads: AdsProviding
    public let audio = AudioManager.shared

    // Camera used for screen shake / future parallax.
    public let gameCamera = SKCameraNode()

    // Live run state (read-only to subclasses).
    public private(set) var phase: GamePhase = .ready
    public private(set) var worldSpeed: CGFloat = 0
    public private(set) var distance: CGFloat = 0
    public private(set) var runCoins: Int = 0
    public private(set) var deaths = 0

    public var autoPlay = false
    /// Attract/demo mode (`-demo`): self-plays without dodging so all screens —
    /// including game over — cycle on their own. Handy for App Preview capture.
    public var demoMode = false

    private var lastUpdate: TimeInterval = 0
    private var didBuild = false
    private var autoRestartCountdown: TimeInterval = -1

    // MARK: Init
    public init(size: CGSize, config: GameConfig, model: GameModel,
                storage: GameStorage, ads: AdsProviding) {
        self.config = config
        self.model = model
        self.storage = storage
        self.ads = ads
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = .zero
    }

    @available(*, unavailable)
    required public init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    // MARK: Lifecycle
    open override func didMove(to view: SKView) {
        backgroundColor = config.background.uiColor
        physicsWorld.contactDelegate = self
        if gameCamera.parent == nil { addChild(gameCamera) }
        camera = gameCamera
        centerCamera()
        demoMode = CommandLine.arguments.contains("-demo")
        autoPlay = CommandLine.arguments.contains("-autoplay") || demoMode

        if !didBuild { buildScene(); didBuild = true }
        layoutScene()
        wireModelCommands()
        enterReady()

        if autoPlay { startRun() }

        // Verification hook: present a rewarded ad a few seconds after launch so
        // we can confirm the real ad pipeline works (Google test ad on sim).
        if CommandLine.arguments.contains("-adtest") {
            run(.sequence([.wait(forDuration: 6),
                           .run { [weak self] in self?.ads.showRewarded { _ in } }]))
        }
    }

    open override func didChangeSize(_ oldSize: CGSize) {
        guard didBuild else { return }
        centerCamera()
        layoutScene()
    }

    private func centerCamera() {
        gameCamera.position = CGPoint(x: size.width / 2, y: size.height / 2)
    }

    private func wireModelCommands() {
        guard let model else { return }
        model.startTapped     = { [weak self] in self?.startRun() }
        model.reviveTapped    = { [weak self] in self?.requestRevive() }
        model.doubleCoinsTapped = { [weak self] in self?.requestDoubleCoins() }
        model.restartTapped   = { [weak self] in self?.restart() }
        model.homeTapped      = { [weak self] in self?.goHome() }
        model.pauseTapped     = { [weak self] in self?.pause() }
        model.resumeTapped    = { [weak self] in self?.resume() }
        model.totalCoins      = storage.coins
        model.bestScore       = storage.bestScore
    }

    // MARK: Phase transitions
    private func enterReady() {
        phase = .ready
        model?.phase = .ready
        resetRunValues()
    }

    public func startRun() {
        resetRunValues()
        phase = .playing
        model?.phase = .playing
        didStartRun()
    }

    private func resetRunValues() {
        distance = 0
        runCoins = 0
        worldSpeed = config.baseSpeed
        lastUpdate = 0
        autoRestartCountdown = -1
        centerCamera()
        model?.score = 0
        model?.runCoins = 0
        model?.canRevive = true
        model?.coinsDoubled = false
        model?.newBest = false
        resetRun() // subclass clears entities + repositions player
    }

    private func die() {
        guard phase == .playing else { return }
        phase = .dead
        deaths += 1
        let finalScore = Int(distance)
        let isBest = storage.submit(score: finalScore)
        GameCenter.shared.submit(score: finalScore)
        Haptics.notify(.error)
        screenShake(intensity: 16, duration: 0.4)
        audio.play("crash")
        model?.score = finalScore
        model?.bestScore = storage.bestScore
        model?.runCoins = runCoins
        model?.totalCoins = storage.coins
        model?.newBest = isBest
        model?.phase = .dead
        if autoPlay { autoRestartCountdown = demoMode ? 3.0 : 1.3 }
    }

    public func restart() {
        if !storage.removeAdsPurchased,
           config.interstitialEveryDeaths > 0,
           deaths % config.interstitialEveryDeaths == 0 {
            ads.showInterstitial { [weak self] in self?.startRun() }
        } else {
            startRun()
        }
    }

    public func goHome() {
        phase = .ready
        model?.phase = .ready
        resetRunValues()
    }

    public func pause() {
        guard phase == .playing else { return }
        phase = .paused
        model?.phase = .paused
        isPaused = true
    }

    public func resume() {
        guard phase == .paused else { return }
        isPaused = false
        lastUpdate = 0
        phase = .playing
        model?.phase = .playing
    }

    // MARK: Rewarded ad actions
    public func requestRevive() {
        guard phase == .dead, model?.canRevive == true else { return }
        ads.showRewarded { [weak self] earned in
            guard let self, earned else { return }
            self.performRevive()
        }
    }

    private func performRevive() {
        model?.canRevive = false
        clearHazardsForRevive()
        lastUpdate = 0
        phase = .playing
        model?.phase = .playing
    }

    public func requestDoubleCoins() {
        guard phase == .dead, model?.coinsDoubled == false, runCoins > 0 else { return }
        ads.showRewarded { [weak self] earned in
            guard let self, earned else { return }
            self.storage.addCoins(self.runCoins) // grant the run's coins a second time
            self.model?.coinsDoubled = true
            self.model?.totalCoins = self.storage.coins
        }
    }

    // MARK: Scoring / coins (called by subclasses)
    /// Bank a collected coin immediately and play feedback.
    public func collectCoin(at point: CGPoint, value: Int = 1) {
        runCoins += value
        storage.addCoins(value)
        model?.runCoins = runCoins
        model?.totalCoins = storage.coins
        Haptics.impact(.light, intensity: 0.6)
        audio.play("coin")
        emitBurst(at: point, color: config.coin.uiColor, count: 6, speed: 90, radius: 2)
    }

    /// Subclass calls this when the player hits a hazard.
    public func killPlayer() { die() }

    // MARK: Update loop
    open override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdate == 0 ? 0 : min(currentTime - lastUpdate, 1.0 / 30.0)
        lastUpdate = currentTime

        if phase == .dead {
            if autoRestartCountdown > 0 {
                autoRestartCountdown -= dt
                if autoRestartCountdown <= 0 { startRun() }
            }
            return
        }

        guard phase == .playing, dt > 0 else { return }

        worldSpeed = min(config.maxSpeed, worldSpeed + config.speedRamp * CGFloat(dt))
        let advance = worldSpeed * CGFloat(dt)

        distance += advance * config.scoreRate
        model?.score = Int(distance)

        tick(dt: CGFloat(dt), advance: advance)

        if autoPlay && !demoMode { autoPilot(dt: CGFloat(dt)) }
    }

    // MARK: Contacts
    public func didBegin(_ contact: SKPhysicsContact) {
        handleContact(contact)
    }

    // MARK: - Hooks for subclasses to override -

    /// Build persistent nodes once (player, lanes, decorations).
    open func buildScene() {}

    /// Position nodes for the current `size`. Called on first show and resize.
    open func layoutScene() {}

    /// Reset entities and place the player at the start of a fresh run.
    open func resetRun() {}

    /// Called right after a run starts (after `resetRun`). Use for one-shot
    /// kick-offs, e.g. enabling gravity or giving an initial impulse.
    open func didStartRun() {}

    /// Per-frame logic while playing: move/cull/spawn the game's entities.
    open func tick(dt: CGFloat, advance: CGFloat) {}

    /// The game's input action during play (flip, jump, switch lane…).
    open func onPlayTap() {}

    /// Remove hazards around the player so a revive is fair.
    open func clearHazardsForRevive() {}

    /// Dispatch a physics contact. Use `collectCoin`/`killPlayer` helpers.
    open func handleContact(_ contact: SKPhysicsContact) {}

    /// Optional dodge AI used only under the `-autoplay` launch arg.
    open func autoPilot(dt: CGFloat) {}

    // MARK: Input
    open override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        switch phase {
        case .ready:   startRun()
        case .playing: onPlayTap()
        case .paused, .dead: break // handled by SwiftUI overlay buttons
        }
    }
}
