import SwiftUI

/// Keeps a fixed layout slot, but removes the glass view after its exit animation.
/// Opacity alone isn't sufficient to retire a system-rendered glass surface.
struct AnimatedGlassTool<Content: View>: View {
    let visible: Bool
    let reduceMotion: Bool
    let content: Content
    @State private var mounted: Bool
    @State private var presented: Bool

    init(visible: Bool, reduceMotion: Bool, content: Content) {
        self.visible = visible
        self.reduceMotion = reduceMotion
        self.content = content
        _mounted = State(initialValue: visible)
        _presented = State(initialValue: visible)
    }

    var body: some View {
        ZStack {
            if mounted {
                content
                    .fixedSize()
                    .frame(width: 52, height: 48, alignment: .center)
                    // Transform the label and system glass as one composited layer.
                    .compositingGroup()
                    .scaleEffect(presented || reduceMotion ? 1 : 0, anchor: .center)
                    .opacity(presented ? 1 : 0)
                    .allowsHitTesting(visible)
                    .accessibilityHidden(!visible)
            }
        }
        .frame(width: 52, height: 48, alignment: .center)
        .contentShape(Rectangle())
        .task(id: visible) {
            if visible {
                guard !presented else { return }
                if !mounted {
                    updateWithoutAnimation { mounted = true }
                    // Let the newly inserted view lay out before animating it in place.
                    do { try await Task.sleep(for: .milliseconds(16)) } catch { return }
                }
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: reduceMotion ? 0.12 : 0.22)) {
                    presented = true
                }
            } else {
                guard mounted else { return }
                withAnimation(.easeInOut(duration: reduceMotion ? 0.12 : 0.22)) { presented = false }
                do { try await Task.sleep(for: .milliseconds(reduceMotion ? 140 : 240)) } catch { return }
                guard !Task.isCancelled else { return }
                updateWithoutAnimation { mounted = false }
            }
        }
    }

    private func updateWithoutAnimation(_ update: () -> Void) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction, update)
    }
}
