import SwiftUI

struct RootView: View {
    @Environment(DeskStore.self) private var store
    @State private var pairingSheet = false
    var body: some View {
        TabView {
            Tab("速记", systemImage: "square.and.pencil") {
                NavigationStack { CaptureView(showPairing: $pairingSheet) }
            }
            Tab("记录", systemImage: "clock.arrow.circlepath") {
                NavigationStack { HistoryView() }
            }
            Tab("桌面", systemImage: "desktopcomputer") {
                NavigationStack { DesktopView(showPairing: $pairingSheet) }
            }
        }
        .sheet(isPresented: $pairingSheet, onDismiss: { importedCode = "" }) { PairingView() }
        .onOpenURL { url in
            let code = Pairing.normalize(url.absoluteString)
            if Pairing.isValid(code) { pairingSheet = true; importedCode = code }
        }
        .environment(\.importedPairingCode, importedCode)
    }
    @State private var importedCode = ""
}

private struct ImportedCodeKey: EnvironmentKey { static let defaultValue = "" }
extension EnvironmentValues {
    var importedPairingCode: String {
        get { self[ImportedCodeKey.self] }
        set { self[ImportedCodeKey.self] = newValue }
    }
}

struct DeskBackdrop: View {
    var body: some View {
        LinearGradient(colors: [Color.green.opacity(0.09), Color(uiColor: .systemGroupedBackground), Color.orange.opacity(0.07)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
    }
}

struct CaptureView: View {
    @Environment(DeskStore.self) private var store
    @Binding var showPairing: Bool
    @FocusState private var editing: Bool
    @State private var clearDraft = false
    var body: some View {
        @Bindable var store = store
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("先记下来。\n回到桌面再继续。")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        Text("给想法留个位置。") .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                if store.code == nil || store.needsPairing {
                    Button { showPairing = true } label: {
                        Label(store.needsPairing ? "重新配对桌面" : "连接我的桌面", systemImage: "link")
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                    }.buttonStyle(.glassProminent).controlSize(.large)
                    Text("在桌面 Mini Desk 的工作区菜单中打开「手机速记」，扫码或输入配对码。")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 16) {
                    Picker("发送类型", selection: $store.kind) {
                        ForEach(CaptureKind.allCases, id: \.self) { kind in
                            Label(kind.title, systemImage: kind.symbol).tag(kind)
                        }
                    }.pickerStyle(.segmented).disabled(store.busy)
                    ZStack(alignment: .topLeading) {
                        if store.draft.isEmpty {
                            Text(store.kind == .todo ? "买一束花\n明天下午三点，给客户回电话…" : "一个突然冒出来的想法…")
                                .foregroundStyle(.tertiary).padding(.top, 12).padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $store.draft).frame(minHeight: 220)
                            .scrollContentBackground(.hidden).focused($editing)
                            .disabled(store.busy).accessibilityLabel("速记内容")
                    }
                    HStack {
                        Text("每行一条 · 每行最多 500 字符") .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        PasteButton(payloadType: String.self) { values in
                            guard let text = values.first else { return }
                            store.draft += (store.draft.isEmpty || store.draft.hasSuffix("\n") ? "" : "\n") + text
                        }.labelStyle(.iconOnly).disabled(store.busy).accessibilityLabel("粘贴内容")
                    }
                }
                .padding(20).background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 26))
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: $store.polish) { Label("AI 整理", systemImage: "sparkles") }.disabled(store.busy)
                    Text(store.polish ? "中转服务将整理文字、拆分条目，并尝试识别提醒时间。" : "按原文发送，保留你的表达。")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(.horizontal, 4)
                if let error = store.error {
                    Label(error, systemImage: "exclamationmark.circle").font(.subheadline).foregroundStyle(.red)
                }
                if let message = store.message {
                    Label(message, systemImage: "checkmark.circle.fill").font(.subheadline).foregroundStyle(.secondary)
                }
                Button {
                    editing = false
                    Task { await store.send() }
                } label: {
                    HStack {
                        if store.busy { ProgressView().tint(.white) } else { Image(systemName: "paperplane.fill") }
                        Text(store.busy ? "正在发送…" : "发送到桌面")
                    }.frame(maxWidth: .infinity).padding(.vertical, 8)
                }.buttonStyle(.glassProminent).controlSize(.large)
                    .disabled(store.busy || store.code == nil || store.needsPairing || store.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Text("通过 HTTPS 发送到中转服务。桌面端定时收取，也可手动同步。")
                    .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
            }.padding(24)
        }
        .background { DeskBackdrop() }
        .navigationTitle("Mini Desk").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showPairing = true } label: { Image(systemName: store.code == nil ? "link.badge.plus" : "link") }
                    .disabled(store.busy).accessibilityLabel("桌面配对")
            }
            ToolbarItemGroup(placement: .keyboard) {
                Button("清空", role: .destructive) { clearDraft = true }.disabled(store.draft.isEmpty || store.busy)
                Spacer()
                Button("完成") { editing = false }
            }
        }
        .confirmationDialog("清空当前草稿？", isPresented: $clearDraft, titleVisibility: .visible) {
            Button("清空草稿", role: .destructive) { store.draft = "" }
        }
    }
}

struct HistoryView: View {
    @Environment(DeskStore.self) private var store
    @State private var confirmClear = false
    @State private var discardID: String?
    var body: some View {
        List {
            Section {
                Text("“已接收”表示中转服务已接收，不代表桌面端已同步。失败的记录可在原配对桌面下重试。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if store.records.isEmpty {
                ContentUnavailableView("还没有发送记录", systemImage: "tray", description: Text("写下第一条提醒或想法，它会出现在这里。"))
            }
            ForEach(store.records) { record in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label(record.payload.kind.title, systemImage: record.payload.kind.symbol).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text(record.accepted ? "中转已接收" : "待重试").font(.caption).foregroundStyle(record.accepted ? .green : .orange)
                    }
                    Text(record.payload.text).textSelection(.enabled)
                    HStack {
                        Text(record.date, format: .dateTime.month().day().hour().minute()).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        if store.canRetry(record) {
                            Button("重试", systemImage: "arrow.clockwise") { Task { await store.retry(record.id) } }
                                .buttonStyle(.glass).disabled(store.busy)
                        }
                    }
                    if let error = record.error { Text(error).font(.caption).foregroundStyle(.red) }
                    if !record.accepted && !store.canRetry(record) {
                        Text("请连接发送时的桌面后重试。") .font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(.vertical, 6)
                    .swipeActions {
                        Button("删除", role: .destructive) { discardID = record.id }.disabled(store.busy)
                    }
            }
        }
        .navigationTitle("发送记录")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("清除已接收", systemImage: "trash") { confirmClear = true }
                    .disabled(store.busy || !store.records.contains { $0.accepted })
            }
        }
        .confirmationDialog("删除这条本机记录？未发送的内容将被丢弃。", isPresented: Binding(get: { discardID != nil }, set: { if !$0 { discardID = nil } }), titleVisibility: .visible) {
            Button("删除记录", role: .destructive) { if let id = discardID { store.discard(id) }; discardID = nil }
        }
        .confirmationDialog("清除本机已接收的记录？", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("清除记录", role: .destructive) { store.clearAccepted() }
        }
    }
}

struct DesktopView: View {
    @Environment(DeskStore.self) private var store
    @Binding var showPairing: Bool
    @State private var disconnect = false
    var body: some View {
        List {
            Section {
                VStack(spacing: 18) {
                    Image(systemName: "desktopcomputer").font(.system(size: 56, weight: .light)).foregroundStyle(.tint)
                        .frame(width: 110, height: 110).glassEffect(.regular, in: RoundedRectangle(cornerRadius: 30))
                    Text(store.code == nil ? "把小事送回桌面" : "桌面已配对").font(.title2.bold())
                    Text("Do less, do it well.").foregroundStyle(.secondary)
                    if let code = store.code { Text(Pairing.masked(code)).font(.system(.body, design: .monospaced)) }
                    Button(store.code == nil ? "配对桌面" : "更换配对") { showPairing = true }
                        .buttonStyle(.glassProminent).controlSize(.large).disabled(store.busy)
                }.frame(maxWidth: .infinity).padding(.vertical, 24)
            }.listRowBackground(Color.clear)
            Section("使用方式") {
                Label("打开桌面端工作区的「手机速记」", systemImage: "1.circle")
                Label("扫描二维码或输入 12 位配对码", systemImage: "2.circle")
                Label("发送提醒或随手记，桌面端同步收取", systemImage: "3.circle")
            }
            Section("数据与隐私") {
                Text("配对码保存在本机钥匙串。草稿和发送记录保存在本机。消息通过 HTTPS 发送，中转服务可读取内容；启用 AI 整理后会交由服务端模型处理。")
                    .font(.footnote).foregroundStyle(.secondary)
                Link("打开 Mini Desk 桌面端", destination: URL(string: "https://minidesk.online")!)
            }
            if store.code != nil {
                Section {
                    Button("断开本机配对", role: .destructive) { disconnect = true }.disabled(store.busy)
                } footer: { Text("只移除本机的配对信息，桌面端配对码仍然有效。") }
            }
        }.navigationTitle("我的桌面")
            .confirmationDialog("断开本机配对？", isPresented: $disconnect, titleVisibility: .visible) {
                Button("断开配对", role: .destructive) { store.unpair() }
            }
    }
}

#Preview { RootView().environment(DeskStore()) }
