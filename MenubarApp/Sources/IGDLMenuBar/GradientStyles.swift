import SwiftUI

let igdlGradient = LinearGradient(
    colors: [Color.blue, Color.indigo],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

/// Solid gradient fill button — used for the one primary action per screen.
struct GradientButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var colors: [Color] = [.blue, .indigo]

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 9)
            .padding(.horizontal, 14)
            .background(
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(
                color: (colors.first ?? .blue).opacity(isEnabled ? 0.35 : 0),
                radius: configuration.isPressed ? 2 : 6,
                y: configuration.isPressed ? 1 : 3
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(isEnabled ? 1 : 0.4)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Gradient-stroked outline button — for secondary actions.
struct GradientOutlineButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var colors: [Color] = [.blue, .indigo]

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1.2
                    )
            )
            .foregroundStyle(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
    }
}

/// Plain text button with a gradient-tinted label, for low-emphasis footer actions.
struct GradientTextButtonStyle: ButtonStyle {
    var colors: [Color] = [.blue, .indigo]

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
