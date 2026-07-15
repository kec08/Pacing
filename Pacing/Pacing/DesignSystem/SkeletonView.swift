import SwiftUI

struct SkeletonBlock: View {
    var width: CGFloat? = nil
    var height: CGFloat
    var cornerRadius: CGFloat = 8

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.gray100)
            .frame(width: width, height: height)
            .skeletonShimmer()
    }
}

struct SkeletonCircle: View {
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(Color.gray100)
            .frame(width: size, height: size)
            .skeletonShimmer()
    }
}

struct SkeletonRow: View {
    var avatarSize: CGFloat = 44
    var trailingWidth: CGFloat? = nil

    var body: some View {
        HStack(spacing: 12) {
            SkeletonCircle(size: avatarSize)

            VStack(alignment: .leading, spacing: 8) {
                SkeletonBlock(width: 120, height: 14, cornerRadius: 7)
                SkeletonBlock(width: 78, height: 11, cornerRadius: 6)
            }

            Spacer()

            if let trailingWidth {
                SkeletonBlock(width: trailingWidth, height: 30, cornerRadius: 15)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct SkeletonShimmer: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { proxy in
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.72),
                            Color.white.opacity(0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .rotationEffect(.degrees(18))
                    .offset(x: proxy.size.width * phase)
                }
                .mask(content)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.15).repeatForever(autoreverses: false)) {
                    phase = 1.8
                }
            }
    }
}

private extension View {
    func skeletonShimmer() -> some View {
        modifier(SkeletonShimmer())
    }
}
