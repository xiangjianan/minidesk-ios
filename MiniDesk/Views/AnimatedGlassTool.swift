import SwiftUI

/// A stable layout slot with an opacity-only insertion and removal transition.
struct AnimatedGlassTool<Content: View>: View {
    let visible: Bool
    let reduceMotion: Bool
    let content: Content

    var body: some View {
        ZStack {
            if visible {
                content
                    .fixedSize()
                    .frame(width: 58, height: 48, alignment: .center)
                    .glassEffectTransition(.identity)
                    .transition(.opacity)
            }
        }
        .frame(width: 58, height: 48, alignment: .center)
        .animation(.easeInOut(duration: reduceMotion ? 0.12 : 0.22), value: visible)
        .allowsHitTesting(visible)
        .accessibilityHidden(!visible)
    }
}
