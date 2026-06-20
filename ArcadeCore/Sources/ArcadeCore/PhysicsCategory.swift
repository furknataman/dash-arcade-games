import Foundation

/// Shared physics bitmasks for all ArcadeCore games.
public enum PhysicsCategory {
    public static let player: UInt32   = 0x1 << 0
    public static let boundary: UInt32 = 0x1 << 1
    public static let obstacle: UInt32 = 0x1 << 2
    public static let coin: UInt32     = 0x1 << 3
    public static let custom: UInt32   = 0x1 << 4
}
