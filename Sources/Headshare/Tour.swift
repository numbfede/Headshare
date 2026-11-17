import SwiftUI

/// Elements of the menu that the Welcome tour can spotlight.
enum TourTarget: Hashable {
    case toggle, outputs, row, connect, settings
}

struct TourAnchorKey: PreferenceKey {
    static var defaultValue: [TourTarget: Anchor<CGRect>] = [:]
    static func reduce(value: inout [TourTarget: Anchor<CGRect>], nextValue: () -> [TourTarget: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    func tourAnchor(_ target: TourTarget, enabled: Bool = true) -> some View {
        transformAnchorPreference(key: TourAnchorKey.self, value: .bounds) { dict, anchor in
            if enabled { dict[target] = anchor }
        }
    }
}

/// Full-area dimming with a rounded hole that animates between targets.
struct SpotlightShape: Shape {
    var hole: CGRect
    var radius: CGFloat = 16

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(AnimatablePair(hole.origin.x, hole.origin.y), AnimatablePair(hole.width, hole.height)) }
        set { hole = CGRect(x: newValue.first.first, y: newValue.first.second, width: newValue.second.first, height: newValue.second.second) }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        path.addRoundedRect(in: hole, cornerSize: CGSize(width: radius, height: radius), style: .continuous)
        return path
    }
}

struct PulsingRing: View {
    let rect: CGRect
    @State private var pulse = false

    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(Color.accentColor, lineWidth: 2.5)
            .shadow(color: Color.accentColor.opacity(0.9), radius: pulse ? 16 : 5)
            .scaleEffect(pulse ? 1.015 : 1)
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) { pulse = true }
            }
    }
}

/// Dims everything except the current target. Clicks pass through, so the highlighted control stays usable.
struct SpotlightOverlay: View {
    let anchors: [TourTarget: Anchor<CGRect>]
    let target: TourTarget?

    var body: some View {
        GeometryReader { proxy in
            if let target, let anchor = anchors[target] {
                let rect = proxy[anchor].insetBy(dx: -6, dy: -6)
                ZStack {
                    SpotlightShape(hole: rect)
                        .fill(Color.black.opacity(0.5), style: FillStyle(eoFill: true))
                    PulsingRing(rect: rect)
                }
                .allowsHitTesting(false)
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: target)
    }
}
