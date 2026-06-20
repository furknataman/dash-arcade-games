import SwiftUI

public extension Color {
    init(_ c: RGBA) {
        self.init(.sRGB, red: c.r, green: c.g, blue: c.b, opacity: c.a)
    }
}

/// Chunky, springy arcade button. Shared by every menu so all games feel
/// consistent and "juicy" with zero per-game work.
public struct ArcadeButtonStyle: ButtonStyle {
    var fill: Color
    var foreground: Color
    var prominent: Bool

    public init(fill: Color, foreground: Color = .white, prominent: Bool = true) {
        self.fill = fill
        self.foreground = foreground
        self.prominent = prominent
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 19, weight: .heavy, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(fill)
                    .shadow(color: prominent ? fill.opacity(0.5) : .clear, radius: 12, y: 6)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// A small pill chip (coins, best score, etc.).
public struct StatChip: View {
    let icon: String
    let text: String
    var tint: Color = .white

    public init(icon: String, text: String, tint: Color = .white) {
        self.icon = icon; self.text = text; self.tint = tint
    }

    public var body: some View {
        HStack(spacing: 6) {
            Text(icon)
            Text(text).font(.system(size: 17, weight: .bold, design: .rounded))
        }
        .foregroundStyle(tint)
        .padding(.vertical, 7)
        .padding(.horizontal, 13)
        .background(Capsule().fill(.black.opacity(0.28)))
    }
}
