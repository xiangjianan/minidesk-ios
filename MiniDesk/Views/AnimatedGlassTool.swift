import SwiftUI
import UIKit

/// Keep the glass mounted and fade its entire UIKit host, rather than asking
/// SwiftUI's separate glass renderer to animate insertion/removal or opacity.
struct AnimatedGlassTool<Content: View>: UIViewControllerRepresentable {
    let visible: Bool
    let reduceMotion: Bool
    let content: Content

    private var hostedContent: some View {
        GlassEffectContainer(spacing: 8) {
            content.frame(width: 58, height: 48, alignment: .center)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(visible: visible) }

    func makeUIViewController(context: Context) -> UIHostingController<AnyView> {
        let controller = UIHostingController(rootView: AnyView(hostedContent))
        controller.view.backgroundColor = .clear
        controller.view.alpha = visible ? 1 : 0
        controller.view.isUserInteractionEnabled = visible
        controller.view.accessibilityElementsHidden = !visible
        return controller
    }

    func updateUIViewController(_ controller: UIHostingController<AnyView>, context: Context) {
        controller.rootView = AnyView(hostedContent)
        let view = controller.view!
        view.isUserInteractionEnabled = visible
        view.accessibilityElementsHidden = !visible
        guard context.coordinator.visible != visible else { return }
        context.coordinator.visible = visible

        // Finish an interrupted fade at its current presentation value. Never
        // jump to the old animation's endpoint when typing or clearing rapidly.
        if let animator = context.coordinator.animator, animator.state == .active {
            animator.stopAnimation(false)
            animator.finishAnimation(at: .current)
        }
        let animator = UIViewPropertyAnimator(duration: reduceMotion ? 0.12 : 0.22,
                                             curve: .easeInOut) {
            view.alpha = visible ? 1 : 0
        }
        context.coordinator.animator = animator
        animator.startAnimation()
    }

    static func dismantleUIViewController(_ controller: UIHostingController<AnyView>, coordinator: Coordinator) {
        if let animator = coordinator.animator, animator.state == .active {
            animator.stopAnimation(true)
        }
    }

    final class Coordinator {
        var visible: Bool
        var animator: UIViewPropertyAnimator?
        init(visible: Bool) { self.visible = visible }
    }
}
