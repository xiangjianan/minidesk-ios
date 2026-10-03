import SwiftUI
import UIKit

/// Native text editing keeps UIKit's grouped typing undo history.
struct ShakeUndoTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var editing: Bool
    var disabled: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> ShakeUndoTextView {
        let view = ShakeUndoTextView()
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.font = .preferredFont(forTextStyle: .body)
        view.adjustsFontForContentSizeCategory = true
        view.textColor = .label
        view.keyboardDismissMode = .interactive
        view.alwaysBounceVertical = true
        view.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        view.accessibilityLabel = "速记内容"
        return view
    }

    func updateUIView(_ view: ShakeUndoTextView, context: Context) {
        context.coordinator.parent = self
        // Don't replace text during typing: doing so destroys the native undo stack.
        if view.text != text {
            view.text = text
            view.undoManager?.removeAllActions()
        }
        view.isEditable = !disabled
        if editing && !disabled && !view.isFirstResponder {
            view.becomeFirstResponder()
        } else if (!editing || disabled) && view.isFirstResponder {
            view.resignFirstResponder()
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: ShakeUndoTextEditor
        init(_ parent: ShakeUndoTextEditor) { self.parent = parent }
        func textViewDidChange(_ textView: UITextView) { parent.text = textView.text }
        func textViewDidBeginEditing(_ textView: UITextView) { parent.editing = true }
        func textViewDidEndEditing(_ textView: UITextView) { parent.editing = false }
    }
}

final class ShakeUndoTextView: UITextView {
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        guard motion == .motionShake, isFirstResponder, isEditable,
              let manager = undoManager, manager.canUndo else {
            super.motionEnded(motion, with: event)
            return
        }
        var responder: UIResponder? = self
        while let current = responder, !(current is UIViewController) { responder = current.next }
        guard let controller = responder as? UIViewController,
              controller.presentedViewController == nil else { return }
        let alert = UIAlertController(title: "撤销输入？", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "撤销", style: .default) { [weak self] _ in
            guard let self, self.undoManager?.canUndo == true else { return }
            self.undoManager?.undo()
        })
        controller.present(alert, animated: true)
    }
}
