import SwiftUI

private enum DeskTab: Hashable { case history, capture, desktop }

struct RootView: View {
    @Environment(DeskStore.self) private var store
    @State private var pairingSheet = false
    @State private var selectedTab: DeskTab = .capture
    @State private var importedCode = ""
    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("记录", systemImage: "clock.arrow.circlepath", value: DeskTab.history) {
                NavigationStack { HistoryView() }
            }
            Tab("速记", systemImage: "square.and.pencil", value: DeskTab.capture) {
                NavigationStack { CaptureView(showPairing: $pairingSheet) }
            }
            Tab("桌面", systemImage: "desktopcomputer", value: DeskTab.desktop) {
                NavigationStack { DesktopView(showPairing: $pairingSheet) }
            }
        }
        .sensoryFeedback(.selection, trigger: selectedTab)
        .sheet(isPresented: $pairingSheet, onDismiss: { importedCode = "" }) { PairingView() }
        .onOpenURL { url in
            let code = Pairing.normalize(url.absoluteString)
            if Pairing.isValid(code) { selectedTab = .capture; pairingSheet = true; importedCode = code }
        }
        .environment(\.importedPairingCode, importedCode)
    }
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
    var body: some View {
        ScrollViewReader { scroll in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if store.code == nil || store.needsPairing { pairingPrompt }
                    ForEach(recentRecords) { record in captureBubble(record) }
                    Color.clear.frame(height: 1).id("latest")
                }.padding(.horizontal, 20).padding(.vertical, 16)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: recentRecords.last?.id) { _, _ in
                withAnimation(.easeOut(duration: 0.2)) { scroll.scrollTo("latest", anchor: .bottom) }
            }
            .onChange(of: editing) { _, focused in
                if focused { withAnimation(.easeOut(duration: 0.2)) { scroll.scrollTo("latest", anchor: .bottom) } }
            }
        }
        .background { DeskBackdrop() }
        .safeAreaInset(edge: .bottom, spacing: 0) { composer }
        .navigationTitle("Mini Desk").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showPairing = true } label: { Image(systemName: store.code == nil ? "link.badge.plus" : "link") }
                    .disabled(store.busy).accessibilityLabel("桌面配对")
            }
        }
    }
    private var pairingPrompt: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("先记下来。\n回到桌面再继续。")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
            Button { showPairing = true } label: {
                Label(store.needsPairing ? "重新配对桌面" : "连接我的桌面", systemImage: "link")
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
            }.buttonStyle(.glassProminent).controlSize(.large)
            Text("在桌面 Mini Desk 的工作区菜单中打开「手机速记」，扫码或输入配对码。")
                .font(.subheadline).foregroundStyle(.secondary)
        }.padding(.vertical, 16)
    }
    private var composer: some View {
        @Bindable var store = store
        return VStack(spacing: 12) {
            if let error = store.error {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(.caption).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading)
            }
            GlassEffectContainer(spacing: 12) {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Picker("发送类型", selection: $store.kind) {
                            ForEach(CaptureKind.allCases, id: \.self) { kind in
                                Label(kind.title, systemImage: kind.symbol).tag(kind)
                            }
                        }.pickerStyle(.segmented).disabled(store.busy)
                        Button { store.polish.toggle() } label: { Label("AI", systemImage: "sparkles") }
                            .buttonStyle(.glass).tint(store.polish ? Color.accentColor : Color.secondary)
                            .disabled(store.busy).accessibilityLabel("AI 整理")
                            .accessibilityValue(store.polish ? "已开启" : "已关闭")
                    }
                    HStack(alignment: .bottom, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField(store.kind == .todo ? "写一条提醒…" : "记下此刻的想法…", text: $store.draft, axis: .vertical)
                                .lineLimit(1...6).focused($editing)
                                .disabled(store.busy).accessibilityLabel("速记内容")
                            HStack(spacing: 14) {
                                PasteButton(payloadType: String.self) { values in
                                    guard let text = values.first else { return }
                                    store.draft += (store.draft.isEmpty || store.draft.hasSuffix("\n") ? "" : "\n") + text
                                }.labelStyle(.iconOnly).controlSize(.mini).disabled(store.busy)
                                    .accessibilityLabel("粘贴内容")
                                Button("清空") { store.draft = "" }
                                    .font(.caption).buttonStyle(.plain).foregroundStyle(.secondary)
                                    .disabled(store.draft.isEmpty || store.busy)
                                Spacer(minLength: 0)
                                if !store.draft.isEmpty {
                                    Text("每行一条").font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(16)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 26))
                        Button(action: sendDraft) {
                            ZStack {
                                Image(systemName: "arrow.up").font(.title3.weight(.semibold))
                                    .opacity(store.busy ? 0 : 1)
                                ProgressView().tint(.white).opacity(store.busy ? 1 : 0)
                            }.frame(width: 28, height: 28)
                        }
                        .buttonStyle(.glassProminent).buttonBorderShape(.circle).controlSize(.large)
                        // Eligibility affects interaction rather than replacing the glass material.
                        .allowsHitTesting(canSend).opacity(canSend || store.busy ? 1 : 0.4)
                        .accessibilityLabel(store.busy ? "正在发送" : "发送到桌面")
                        .accessibilityHint(canSend ? "收起键盘并发送当前内容" : "配对桌面并输入内容后可发送")
                        .transaction { $0.animation = nil }
                    }
                }
            }
        }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 12)
    }
    private var recentRecords: [Delivery] {
        guard let code = store.code else { return [] }
        let hash = Pairing.hash(code)
        return Array(store.records.filter { $0.hash == hash }.prefix(20).reversed())
    }
    private func captureBubble(_ record: Delivery) -> some View {
        HStack {
            Spacer(minLength: 40)
            VStack(alignment: .leading, spacing: 10) {
                Label(record.payload.kind.title, systemImage: record.payload.kind.symbol)
                    .font(.caption).foregroundStyle(.secondary)
                Text(record.payload.text).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    Text(record.date, format: .dateTime.hour().minute().locale(Locale(identifier: "zh_CN")))
                        .font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    if record.accepted {
                        Image(systemName: "checkmark").font(.caption).foregroundStyle(.secondary)
                            .accessibilityLabel("中转已接收，等待桌面同步")
                    } else if store.busy && record.error == nil {
                        ProgressView().controlSize(.mini)
                    } else if store.canRetry(record) {
                        Button("重试", systemImage: "arrow.clockwise") { Task { await store.retry(record.id) } }
                            .font(.caption).disabled(store.busy)
                    }
                }
            }.padding(16)
                .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 22))
        }
    }
    private var canSend: Bool {
        !store.busy && store.code != nil && !store.needsPairing &&
        !store.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private func sendDraft() {
        guard canSend else { return }
        editing = false
        Task { await store.send() }
    }
}

struct HistoryView: View {
    @Environment(DeskStore.self) private var store
    @State private var confirmClear = false
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
                        Text(record.date, formatter: Self.recordDateFormatter).font(.caption).foregroundStyle(.secondary)
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
                        Button("删除", role: .destructive) { store.discard(record.id) }.disabled(store.busy)
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
        .alert("删除已接收的发送记录？", isPresented: $confirmClear) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) { store.clearAccepted() }
        } message: {
            Text("将删除本机所有已接收的记录。待重试的内容会保留。")
        }
    }
    private static let recordDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter
    }()

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
