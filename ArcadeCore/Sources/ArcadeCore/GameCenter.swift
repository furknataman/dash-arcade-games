import GameKit

/// Game Center wrapper: authenticate, submit best scores, show the leaderboard.
/// Reusable across games — pass a leaderboard id from `GameConfig`. All calls
/// no-op safely until the player is authenticated.
@MainActor
public final class GameCenter: NSObject, ObservableObject, GKGameCenterControllerDelegate {
    public static let shared = GameCenter()

    @Published public private(set) var isAuthenticated = false
    /// Set when the player taps the leaderboard but isn't signed in, so the UI
    /// can prompt them to sign in to Game Center.
    @Published public var needsSignIn = false
    private var leaderboardID: String?

    /// Begin authentication. Presents Apple's sign-in UI if needed.
    public func start(leaderboardID: String?) {
        self.leaderboardID = leaderboardID
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, _ in
            if let viewController { AppPresenter.present(viewController) }
            self?.isAuthenticated = GKLocalPlayer.local.isAuthenticated
        }
    }

    /// Submit a score; Game Center keeps the player's best automatically.
    public func submit(score: Int) {
        guard isAuthenticated, let id = leaderboardID, score > 0 else { return }
        Task {
            try? await GKLeaderboard.submitScore(score, context: 0,
                                                 player: GKLocalPlayer.local,
                                                 leaderboardIDs: [id])
        }
    }

    /// Tap entry point: show the board if signed in, otherwise try to sign in
    /// first (presents Apple's UI), then show it.
    public func openLeaderboard() {
        if isAuthenticated {
            showLeaderboard()
            return
        }
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, _ in
            if let viewController { AppPresenter.present(viewController); return }
            let ok = GKLocalPlayer.local.isAuthenticated
            self?.isAuthenticated = ok
            if ok { self?.showLeaderboard() } else { self?.needsSignIn = true }
        }
    }

    /// Present the Game Center leaderboard UI.
    public func showLeaderboard() {
        guard isAuthenticated else { return }
        let vc: GKGameCenterViewController
        if let id = leaderboardID {
            vc = GKGameCenterViewController(leaderboardID: id, playerScope: .global, timeScope: .allTime)
        } else {
            vc = GKGameCenterViewController(state: .leaderboards)
        }
        vc.gameCenterDelegate = self
        AppPresenter.present(vc)
    }

    public func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}
