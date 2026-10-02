import SwiftUI

struct PairingView: View {
    var required = false
    @Environment(DeskStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.importedPairingCode) private var imported
    @State private var input = ""
    @State private var scanning = false
    @State private var copyFeedbackID = 0
    private let desktopAddress = "https://minidesk.online"
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("连接你的电脑").font(.title2.bold())
                    pairingStep(1, title: "电脑：打开 MiniDesk", description: "在电脑浏览器访问 minidesk.online。") {
                        Button {
                            UIPasteboard.general.string = desktopAddress
                            copyFeedbackID += 1
                        } label: {
                            Label("复制桌面端地址", systemImage: "doc.on.clipboard")
                                .frame(maxWidth: .infinity)
                        }.buttonStyle(.glass).controlSize(.large)
                    }
                    pairingStep(2, title: "电脑：获取配对码", description: "工作区菜单 →「手机速记」。") {}
                    pairingStep(3, title: "手机：连接电脑", description: "扫码或输入配对码，也可粘贴配对链接。") {
                        Button { scanning = true } label: {
                            Label("扫描桌面二维码", systemImage: "qrcode.viewfinder")
                                .frame(maxWidth: .infinity)
                        }.buttonStyle(.glass).controlSize(.large).disabled(store.busy)
                        PairingCodeField(input: $input).disabled(store.busy)
                        Button {
                            Task {
                                await store.pair(input)
                                if !required && store.code == Pairing.normalize(input) && store.error == nil { dismiss() }
                            }
                        } label: {
                            HStack {
                                if store.busy { ProgressView() }
                                Text(store.busy ? "验证中…" : "连接桌面")
                            }.frame(maxWidth: .infinity)
                        }.buttonStyle(.glassProminent).controlSize(.large)
                            .disabled(store.busy || !Pairing.isValid(Pairing.normalize(input)))
                        if let error = store.error {
                            Text(error).foregroundStyle(.red).font(.subheadline)
                        }
                    }
                }.padding(24)
            }
                .scrollDismissesKeyboard(.interactively)
                .scrollBounceBehavior(.always)
                .background { DeskBackdrop() }
                .navigationTitle(required ? "MiniDesk" : "配对桌面").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if !required {
                        ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() }.disabled(store.busy) }
                    }
                }
        }
        .modifier(CopyFeedback(trigger: copyFeedbackID, detail: desktopAddress))
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

    private func pairingStep<Content: View>(_ number: Int, title: String, description: String,
                                           @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("\(number)").font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28, height: 28)
                    .background(Color.accentColor.opacity(0.12), in: Circle())
                    .accessibilityLabel("第 \(number) 步")
                Text(title).font(.headline)
            }
            Text(description).font(.subheadline).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            content()
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

}

private struct PairingCodeField: View {
    @Binding var input: String
    @FocusState private var focused: Bool

    private var characters: [Character] { Array(Pairing.normalize(input).prefix(12)) }

    var body: some View {
        TextField("", text: $input)
            .keyboardType(.asciiCapable)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .foregroundStyle(.clear).tint(.clear)
            .focused($focused)
            .frame(height: 48)
            .overlay {
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { group in
                        if group > 0 {
                            Text("–").font(.caption).foregroundStyle(.secondary)
                                .frame(width: 6)
                        }
                        HStack(spacing: 3) {
                            ForEach(0..<4, id: \.self) { offset in
                                let index = group * 4 + offset
                                let active = focused && index == min(characters.count, 11)
                                Text(index < characters.count ? String(characters[index]) : " ")
                                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity).frame(height: 44)
                                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 7))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 7)
                                            .strokeBorder(active ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: active ? 2 : 1)
                                    }
                            }
                        }.frame(maxWidth: .infinity)
                    }
                }.allowsHitTesting(false).accessibilityHidden(true)
            }
            .accessibilityLabel("12 位配对码，也可粘贴配对链接")
            .accessibilityValue(Pairing.normalize(input))
            .onChange(of: input) { _, value in
                let normalized = String(Pairing.normalize(value).replacingOccurrences(of: "-", with: "").prefix(12))
                if input != normalized { input = normalized }
            }
    }
}
