import SwiftUI

private enum DeskTab: Hashable { case history, capture, desktop }

struct RootView: View {
    @Environment(DeskStore.self) private var store
    @State private var pairingSheet = false
    @State private var selectedTab: DeskTab = .capture
    @State private var importedCode = ""
    @State private var captureEditing = false
    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("记录", systemImage: "clock.arrow.circlepath", value: DeskTab.history) {
                NavigationStack { HistoryView() }
            }
            Tab("速记", systemImage: "square.and.pencil", value: DeskTab.capture) {
                NavigationStack { CaptureView(showPairing: $pairingSheet, isEditing: $captureEditing) }
            }
            Tab("配对", systemImage: "desktopcomputer", value: DeskTab.desktop) {
                NavigationStack { DesktopView(showPairing: $pairingSheet) }
            }
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.85), trigger: selectedTab)
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
        LinearGradient(colors: [Color.accentColor.opacity(0.09), Color(uiColor: .systemGroupedBackground), Color.blue.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
    }
}

struct CaptureView: View {
    @Environment(DeskStore.self) private var store
    @Binding var showPairing: Bool
    @Binding var isEditing: Bool
    @FocusState private var editing: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasClipboardText = UIPasteboard.general.hasStrings || UIPasteboard.general.hasURLs
    @State private var showsSendSuccess = false
    @State private var successFeedbackID = 0
    @State private var showsPasteError = false
    @State private var pasteErrorID = 0
    var body: some View {
        @Bindable var store = store
        VStack(spacing: 0) {
            Picker("发送类型", selection: $store.kind) {
                ForEach(CaptureKind.allCases, id: \.self) { kind in
                    Label(kind.title, systemImage: kind.symbol).tag(kind)
                }
            }.pickerStyle(.segmented).disabled(store.busy)
                .sensoryFeedback(.impact(weight: .light, intensity: 0.85), trigger: store.kind)
                .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 16)
            if store.code == nil || store.needsPairing {
                Button {
                    editing = false
                    showPairing = true
                } label: {
                    Label(store.needsPairing ? "重新配对桌面" : "连接我的桌面", systemImage: "link")
                }.buttonStyle(.glass).disabled(store.busy).padding(.bottom, 12)
            }
            ZStack(alignment: .topLeading) {
                TextEditor(text: $store.draft)
                    .font(.body).scrollContentBackground(.hidden)
                    .scrollDismissesKeyboard(.interactively)
                    .scrollBounceBehavior(.always)
                    .focused($editing).disabled(store.busy)
                    .accessibilityLabel("速记内容")
                    .padding(.horizontal, 20)
                if store.draft.isEmpty && !showsSendSuccess {
                    Text(store.kind == .todo ? "写下要做的事…" : "记下此刻的想法…")
                        .font(.body).foregroundStyle(.tertiary)
                        .padding(.horizontal, 25).padding(.top, 8)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .top) {
                if showsSendSuccess {
                    SuccessNotice(text: "消息已发送", symbol: "checkmark.circle.fill")
                        .padding(.top, 8)
                        .transition(.opacity)
                }
            }
            .contentShape(Rectangle())
            .simultaneousGesture(TapGesture().onEnded { if !store.busy { editing = true } })
        }
        .background { DeskBackdrop() }
        .safeAreaInset(edge: .bottom, spacing: 0) { editingTools }
        .navigationTitle("MiniDesk").navigationBarTitleDisplayMode(.inline)
        .toolbar(isEditing ? .hidden : .visible, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { store.polish.toggle() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(store.polish
                                ? AnyShapeStyle(LinearGradient(colors: [.pink, .purple, .blue, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                                : AnyShapeStyle(Color.secondary))
                        Text("AI润色").foregroundStyle(store.polish ? Color.primary : Color.secondary)
                    }.font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .glassEffect(.regular.interactive(), in: Capsule())
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(store.busy).accessibilityLabel("AI 润色")
                .accessibilityValue(store.polish ? "已开启" : "已关闭")
                .accessibilityAddTraits(store.polish ? [.isSelected] : [])
                .sensoryFeedback(.impact(weight: .light, intensity: 0.85), trigger: store.polish)
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .onChange(of: store.draft) { _, draft in
            if !draft.isEmpty {
                withAnimation(.easeOut(duration: 0.2)) { showsSendSuccess = false }
            }
        }
        .onChange(of: editing) { _, focused in
            withAnimation(.easeInOut(duration: 0.25)) { isEditing = focused }
        }
        .onAppear { refreshClipboardAvailability() }
        .onReceive(NotificationCenter.default.publisher(for: UIPasteboard.changedNotification)) { _ in
            refreshClipboardAvailability(animated: scenePhase == .active)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshClipboardAvailability() }
        }
        .task(id: successFeedbackID) {
            guard successFeedbackID > 0 else { return }
            do {
                try await Task.sleep(for: .seconds(1.6))
                withAnimation(.easeOut(duration: 0.2)) { showsSendSuccess = false }
            } catch { /* A new send or leaving the page cancels the previous timeout. */ }
        }
        .task(id: pasteErrorID) {
            guard pasteErrorID > 0 else { return }
            do {
                try await Task.sleep(for: .seconds(3))
                withAnimation(.easeInOut(duration: 0.2)) { showsPasteError = false }
            } catch {}
        }
        .onDisappear { editing = false; isEditing = false; showsSendSuccess = false; showsPasteError = false }
    }
    private var editingTools: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showsPasteError {
                Text("剪贴板没有可粘贴的文本")
                    .font(.caption).foregroundStyle(.red).transition(.opacity)
            }
            if let error = store.error {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(.caption).foregroundStyle(.red)
            }
            Group {
                HStack(spacing: 8) {
                    animatedTool(visible: !store.draft.isEmpty) {
                        Button { store.draft = "" } label: {
                            toolSurface(destructive: true) { Image(systemName: "trash") }
                        }.buttonStyle(.plain).allowsHitTesting(!store.busy)
                            .accessibilityLabel("清空草稿")
                    }
                    Spacer(minLength: 8)
                    animatedTool(visible: hasClipboardText) {
                        Button(action: pasteDraft) {
                            toolSurface { Image(systemName: "doc.on.clipboard") }
                        }.buttonStyle(.plain).disabled(store.busy).accessibilityLabel("粘贴文本")
                    }
                    animatedTool(visible: !store.draft.isEmpty) {
                        Button(action: sendDraft) {
                            toolSurface(tinted: true) {
                                ZStack {
                                    Image(systemName: "paperplane.fill").opacity(store.busy ? 0 : 1)
                                    ProgressView().tint(.white).controlSize(.small).opacity(store.busy ? 1 : 0)
                                }
                            }
                        }.buttonStyle(.plain).allowsHitTesting(canSend)
                            .opacity(canSend || store.busy ? 1 : 0.4)
                            .accessibilityLabel(store.busy ? "正在发送" : "发送到桌面")
                            .accessibilityHint("收起键盘并发送当前内容")
                    }
                }
                .overlay(alignment: .center) {
                    animatedTool(visible: editing) {
                        Button { editing = false } label: {
                            toolSurface { Image(systemName: "keyboard.chevron.compact.down") }
                        }.buttonStyle(.plain).accessibilityLabel("收起键盘")
                    }
                }
            }
        }.padding(.horizontal, 20).padding(.vertical, 8)
    }
    private func animatedTool<Content: View>(visible: Bool, @ViewBuilder content: () -> Content) -> some View {
        AnimatedGlassTool(visible: visible, reduceMotion: reduceMotion, content: content())
            .frame(width: 58, height: 48)
    }
    private var toolAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.34, dampingFraction: 0.82)
    }
    private func toolSurface<Content: View>(tinted: Bool = false, destructive: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        content().font(.system(size: 17, weight: .medium))
            .frame(width: 58, height: 44)
            .foregroundStyle(destructive ? Color.red : (tinted ? Color.white : Color.primary))
            .glassEffect(tinted ? .regular.tint(Color.accentColor).interactive() : .regular.interactive(),
                         in: Capsule())
    }
    private func refreshClipboardAvailability(animated: Bool = false) {
        // Appearance/resume checks must never animate the initial screen layout.
        var transaction = Transaction(animation: animated ? toolAnimation : nil)
        transaction.disablesAnimations = !animated
        withTransaction(transaction) {
            hasClipboardText = UIPasteboard.general.hasStrings || UIPasteboard.general.hasURLs
        }
    }
    private func pasteDraft() {
        guard !store.busy else { return }
        guard let text = UIPasteboard.general.string ?? UIPasteboard.general.url?.absoluteString, !text.isEmpty else {
            withAnimation(.easeInOut(duration: 0.2)) { showsPasteError = true }
            pasteErrorID += 1
            refreshClipboardAvailability(animated: true)
            return
        }
        store.error = nil
        withAnimation(.easeInOut(duration: 0.2)) { showsPasteError = false }
        store.draft += (store.draft.isEmpty || store.draft.hasSuffix("\n") ? "" : "\n") + text
    }
    private var canSend: Bool {
        !store.busy && store.code != nil && !store.needsPairing &&
        !store.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private func sendDraft() {
        guard canSend else { return }
        editing = false
        Task {
            await store.send()
            if store.error == nil, store.message != nil {
                withAnimation(.easeOut(duration: 0.2)) { showsSendSuccess = true }
                successFeedbackID += 1
            }
        }
    }
}

struct HistoryView: View {
    @Environment(DeskStore.self) private var store
    @State private var confirmClear = false
    @State private var copyFeedbackID = 0
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
                    Text(record.payload.text)
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
                    .contentShape(Rectangle())
                    .onTapGesture {
                        UIPasteboard.general.string = record.payload.text
                        copyFeedbackID += 1
                    }
                    .accessibilityHint("轻点复制内容")
                    .accessibilityAddTraits(.isButton)
                    .swipeActions {
                        Button("删除", role: .destructive) { store.discard(record.id) }
                            .tint(.red).disabled(store.busy)
                    }
            }
        }
        .navigationTitle("发送记录")
        .modifier(CopyFeedback(trigger: copyFeedbackID))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("清除已接收", systemImage: "trash") { confirmClear = true }.tint(.red)
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
    @State private var copyFeedbackID = 0
    var body: some View {
        List {
            Section {
                VStack(spacing: 18) {
                    Image(systemName: "desktopcomputer").font(.system(size: 56, weight: .light)).foregroundStyle(.tint)
                        .frame(width: 110, height: 110).glassEffect(.regular, in: RoundedRectangle(cornerRadius: 30))
                    Text(store.code == nil ? "把小事送回桌面" : "桌面已配对").font(.title2.bold())
                    Text("Do less, do it well.").foregroundStyle(.secondary)
                    if let code = store.code {
                        Button {
                            UIPasteboard.general.string = code
                            copyFeedbackID += 1
                        } label: {
                            Text(Pairing.masked(code)).font(.system(.body, design: .monospaced))
                        }.buttonStyle(.plain)
                            .accessibilityLabel("配对码")
                            .accessibilityHint("轻点复制完整配对码")
                    }
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
            }
            Section {
                Button("复制桌面端地址", systemImage: "doc.on.clipboard") {
                    UIPasteboard.general.string = "https://minidesk.online"
                    copyFeedbackID += 1
                }
            } footer: {
                Text("请在电脑浏览器中打开 minidesk.online，再通过「手机速记」与此 iPhone 配对。")
            }
            if store.code != nil {
                Section {
                    Button("断开本机配对", role: .destructive) { disconnect = true }.disabled(store.busy)
                } footer: { Text("只移除本机的配对信息，桌面端配对码仍然有效。") }
            }
        }.navigationTitle("配对")
            .scrollIndicators(.hidden)
            .modifier(CopyFeedback(trigger: copyFeedbackID))
            .alert("断开本机配对？", isPresented: $disconnect) {
                Button("取消", role: .cancel) {}
                Button("断开配对", role: .destructive) { store.unpair() }
            } message: {
                Text("只移除本机的配对信息，桌面端配对码仍然有效。")
            }
    }
}

private struct SuccessNotice: View {
    let text: String
    let symbol: String
    var body: some View {
        Label(text, systemImage: symbol)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18).padding(.vertical, 12)
            .glassEffect(.regular.tint(Color.accentColor), in: Capsule())
            .shadow(color: Color.accentColor.opacity(0.2), radius: 10, y: 3)
            .allowsHitTesting(false)
            .accessibilityAddTraits(.updatesFrequently)
    }
}

private struct CopyFeedback: ViewModifier {
    let trigger: Int
    @State private var visible = false
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if visible {
                    SuccessNotice(text: "文本已复制到剪贴板", symbol: "checkmark.circle.fill")
                        .padding(.top, 8).transition(.opacity)
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: trigger)
            .task(id: trigger) {
                guard trigger > 0 else { return }
                withAnimation(.easeInOut(duration: 0.2)) { visible = true }
                do {
                    try await Task.sleep(for: .seconds(2))
                    withAnimation(.easeInOut(duration: 0.2)) { visible = false }
                } catch {}
            }
    }
}

#Preview { RootView().environment(DeskStore()) }
