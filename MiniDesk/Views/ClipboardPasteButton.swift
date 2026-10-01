import SwiftUI
import UIKit

/// Uses iOS's authorized paste control with a transparent fill so system glass
/// can supply the surface without adding another opaque button background.
struct ClipboardPasteButton: UIViewRepresentable {
    var enabled: Bool
    let onPaste: (String) -> Void

    func makeUIView(context: Context) -> ClipboardPasteView { ClipboardPasteView(onPaste: onPaste) }
    func updateUIView(_ view: ClipboardPasteView, context: Context) {
        view.onPaste = onPaste
        view.control.isEnabled = enabled
    }
}

final class ClipboardPasteView: UIView {
    let control: UIPasteControl
    var onPaste: (String) -> Void

    init(onPaste: @escaping (String) -> Void) {
        self.onPaste = onPaste
        let configuration = UIPasteControl.Configuration()
        configuration.displayMode = .iconOnly
        configuration.cornerStyle = .capsule
        configuration.baseBackgroundColor = .clear
        configuration.baseForegroundColor = .label
        control = UIPasteControl(configuration: configuration)
        super.init(frame: .zero)
        pasteConfiguration = UIPasteConfiguration(forAccepting: NSString.self)
        control.target = self
        control.accessibilityLabel = "粘贴内容"
        control.translatesAutoresizingMaskIntoConstraints = false
        addSubview(control)
        NSLayoutConstraint.activate([
            control.leadingAnchor.constraint(equalTo: leadingAnchor),
            control.trailingAnchor.constraint(equalTo: trailingAnchor),
            control.topAnchor.constraint(equalTo: topAnchor),
            control.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }
    override func paste(itemProviders: [NSItemProvider]) {
        guard control.isEnabled, let provider = itemProviders.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else { return }
        provider.loadObject(ofClass: NSString.self) { [weak self] value, _ in
            guard let value = value as? String else { return }
            DispatchQueue.main.async { self?.onPaste(value) }
        }
    }
}
