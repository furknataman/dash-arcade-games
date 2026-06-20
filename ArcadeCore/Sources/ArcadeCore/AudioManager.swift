import AVFoundation

/// Plays short SFX from the main bundle. If a named file is missing it simply
/// no-ops, so a game can ship before its audio assets land. Uses an ambient,
/// mixable session so it never interrupts the user's music.
public final class AudioManager {
    public static let shared = AudioManager()

    public var enabled = true
    private var players: [String: AVAudioPlayer] = [:]
    private var didConfigureSession = false

    private init() {}

    private func configureSessionIfNeeded() {
        guard !didConfigureSession else { return }
        didConfigureSession = true
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    public func preload(_ names: [String], ext: String = "wav") {
        for name in names { _ = player(for: name, ext: ext) }
    }

    private func player(for name: String, ext: String) -> AVAudioPlayer? {
        if let existing = players[name] { return existing }
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { return nil }
        guard let p = try? AVAudioPlayer(contentsOf: url) else { return nil }
        p.prepareToPlay()
        players[name] = p
        return p
    }

    public func play(_ name: String, ext: String = "wav", volume: Float = 1.0) {
        guard enabled else { return }
        configureSessionIfNeeded()
        guard let p = player(for: name, ext: ext) else { return }
        p.volume = volume
        p.currentTime = 0
        p.play()
    }
}
