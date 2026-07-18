import SwiftUI

struct PacingBrandMark: View {
    var size: CGFloat = 96

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
                .fill(Color.pacingGradient)

            Text("P")
                .font(.system(size: size * 0.64, weight: .black, design: .rounded))
                .italic()
                .foregroundStyle(.white)
                .offset(x: -size * 0.015, y: size * 0.015)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Pacing")
    }
}

struct PacingSurfaceCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(Color.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.75), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.06), radius: 16, y: 7)
    }
}

struct PacingPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}
