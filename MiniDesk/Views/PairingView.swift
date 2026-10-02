import SwiftUI

struct PairingView: View {
    var required = false
    @Environment(DeskStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.importedPairingCode) private var imported
    @State private var input = ""
    @State private var scanning = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image(systemName: "link").font(.system(size: 44)).foregroundStyle(.tint)
                        .frame(width: 90, height: 90).glassEffect(.regular, in: RoundedRectangle(cornerRadius: 26))
                    Text("和你的桌面\n建立连接。") .font(.largeTitle.bold())
                    Text("打开桌面端工作区菜单中的「手机速记」，获取二维码或 12 位配对码。") .foregroundStyle(.secondary)
                    TextField("例如 ABCD EFGH 2345", text: $input)
                        .font(.system(.title3, design: .monospaced)).textInputAutocapitalization(.characters)
                        .autocorrectionDisabled().textFieldStyle(.roundedBorder)
                        .accessibilityLabel("配对码或配对链接").disabled(store.busy)
                    Button { scanning = true } label: {
                        Label("扫描桌面二维码", systemImage: "qrcode.viewfinder").frame(maxWidth: .infinity)
                    }.buttonStyle(.glass).controlSize(.large).disabled(store.busy)
                    if let error = store.error { Text(error).foregroundStyle(.red).font(.subheadline) }
                    Button {
                        Task {
                            await store.pair(input)
                            if !required && store.code == Pairing.normalize(input) && store.error == nil { dismiss() }
                        }
                    } label: {
                        HStack { if store.busy { ProgressView() }; Text(store.busy ? "验证中…" : "连接桌面") }
                            .frame(maxWidth: .infinity)
                    }.buttonStyle(.glassProminent).controlSize(.large)
                        .disabled(store.busy || !Pairing.isValid(Pairing.normalize(input)))
                    Text(required ? "配对成功后即可使用速记和历史记录。支持粘贴桌面生成的配对链接。" : "支持直接粘贴桌面生成的配对链接。一次连接一个工作区。") .font(.caption).foregroundStyle(.secondary)
                }.padding(28)
            }.background { DeskBackdrop() }
                .navigationTitle(required ? "MiniDesk" : "配对桌面").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if !required {
                        ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() }.disabled(store.busy) }
                    }
                }
        }
        .interactiveDismissDisabled(store.busy)
        .onAppear { store.error = nil; if !imported.isEmpty { input = imported } }
        .onChange(of: imported) { _, code in
            if !code.isEmpty { input = code }
        }
        .sheet(isPresented: $scanning) {
            QRScannerView { value in
                let normalized = Pairing.normalize(value)
                guard Pairing.isValid(normalized) else { store.error = "二维码不是有效的 MiniDesk 配对链接。"; scanning = false; return }
                input = normalized; scanning = false
            }
        }
    }
}
