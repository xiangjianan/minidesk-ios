import SwiftUI
@preconcurrency import AVFoundation

struct QRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    let onCode: (String) -> Void
    var body: some View {
        NavigationStack {
            ScannerRepresentable(onCode: onCode).ignoresSafeArea(edges: .bottom)
                .navigationTitle("扫描配对二维码").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
        }
    }
}

private struct ScannerRepresentable: UIViewControllerRepresentable {
    let onCode: (String) -> Void
    func makeUIViewController(context: Context) -> ScannerController { ScannerController(onCode: onCode) }
    func updateUIViewController(_ uiViewController: ScannerController, context: Context) {}
    static func dismantleUIViewController(_ controller: ScannerController, coordinator: ()) { controller.stop() }
}

private final class ScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "online.minidesk.camera")
    private var preview: AVCaptureVideoPreviewLayer?
    private let onCode: (String) -> Void
    private var completed = false
    private let hint = UILabel()
    init(onCode: @escaping (String) -> Void) { self.onCode = onCode; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }
    override func viewDidLoad() {
        super.viewDidLoad(); view.backgroundColor = .black
        hint.text = "将桌面端二维码放入画面中"; hint.textColor = .white; hint.numberOfLines = 0; hint.textAlignment = .center
        hint.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(hint)
        NSLayoutConstraint.activate([hint.centerXAnchor.constraint(equalTo: view.centerXAnchor), hint.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24), hint.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40)])
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: configure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async { if granted { self?.configure() } else { self?.showDenied() } }
            }
        default: showDenied()
        }
    }
    private func showDenied() { hint.text = "无法使用相机。请在系统设置中允许相机权限，或关闭此页面手动输入配对码。" }
    private func configure() {
        guard !completed, let device = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else { hint.text = "此设备无法使用相机，请手动输入配对码。"; return }
        session.beginConfiguration(); session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { session.commitConfiguration(); hint.text = "无法启动扫码，请手动输入配对码。"; return }
        session.addOutput(output); output.setMetadataObjectsDelegate(self, queue: .main); output.metadataObjectTypes = [.qr]; session.commitConfiguration()
        let layer = AVCaptureVideoPreviewLayer(session: session); layer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(layer, at: 0); preview = layer; layer.frame = view.bounds
        let session = session; queue.async { session.startRunning() }
    }
    override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews(); preview?.frame = view.bounds }
    func stop() { completed = true; let session = session; queue.async { session.stopRunning() } }
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !completed, let code = (metadataObjects.first as? AVMetadataMachineReadableCodeObject)?.stringValue else { return }
        stop(); onCode(code)
    }
}
