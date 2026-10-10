import SwiftUI

private enum DeskTab: Hashable { case history, capture, desktop }

struct RootView: View {
    @Environment(DeskStore.self) private var store
    @State private var pairingSheet = false
    @State private var selectedTab: DeskTab = .desktop
    @State private var selectedInitialTab = false
    @State private var importedCode = ""
    var body: some View {
        Group {
            if store.isPaired {
                TabView(selection: $selectedTab) {
                    Tab("配对", systemImage: "desktopcomputer", value: DeskTab.desktop) {
                        NavigationStack { DesktopView(showPairing: $pairingSheet) }
                    }
                    Tab("速记", systemImage: "square.and.pencil", value: DeskTab.capture) {
                        NavigationStack { CaptureView(showPairing: $pairingSheet) }
                    }
                    Tab("历史", systemImage: "clock.arrow.circlepath", value: DeskTab.history) {
                        NavigationStack { HistoryView() }
                    }
                }
            } else {
                PairingView(required: true)
            }
        }
        .onAppear {
            guard !selectedInitialTab else { return }
            selectedInitialTab = true
            selectedTab = store.isPaired ? .capture : .desktop
        }
        .onChange(of: store.isPaired) { _, paired in
            selectedTab = paired ? .capture : .desktop
            if !paired { pairingSheet = false }
            if paired { importedCode = "" }
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.85), trigger: selectedTab)
        .sheet(isPresented: $pairingSheet, onDismiss: { importedCode = "" }) { PairingView() }
        .onOpenURL { url in
            let code = Pairing.normalize(url.absoluteString)
            if Pairing.isValid(code) {
                importedCode = code
                if store.isPaired { selectedTab = .capture; pairingSheet = true }
            }
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
    @State private var editing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasClipboardText = UIPasteboard.general.hasStrings || UIPasteboard.general.hasURLs
    @State private var showsSendSuccess = false
    @State private var successFeedbackID = 0
    @State private var showsPasteError = false
    @State private var pasteErrorID = 0
    @State private var clearedDraft: String?
    @State private var clearUndoDeadline: Date?
    var body: some View {
        @Bindable var store = store
        VStack(spacing: 0) {
            if store.isPaired {
                Picker("发送类型", selection: $store.kind) {
                    ForEach(CaptureKind.allCases, id: \.self) { kind in
                        Label(kind.title, systemImage: kind.symbol).tag(kind)
                    }
                }.pickerStyle(.segmented).disabled(store.busy)
                    .sensoryFeedback(.impact(weight: .light, intensity: 0.85), trigger: store.kind)
                    .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 16)
                ZStack(alignment: .topLeading) {
                    ShakeUndoTextEditor(text: $store.draft, editing: $editing, disabled: store.busy)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                .simultaneousGesture(TapGesture().onEnded { if store.isPaired && !store.busy { editing = true } })
                .simultaneousGesture(
                    DragGesture(minimumDistance: 30).onEnded { gesture in
                        guard store.isPaired, !store.busy else { return }
                        let horizontal = gesture.translation.width
                        let vertical = gesture.translation.height
                        // Only deliberate horizontal swipes change the capture type.
                        // Vertical drags remain available for scrolling and keyboard dismissal.
                        guard abs(horizontal) >= 60, abs(horizontal) > abs(vertical) * 1.5 else { return }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            store.kind = horizontal > 0 ? .todo : .note
                        }
                    }
                )
            } else {
                ContentUnavailableView {
                    Label(store.needsPairing ? "需要重新配对" : "配对后才能使用速记", systemImage: "lock.fill")
                } description: {
                    Text(store.needsPairing ? "当前配对已失效，请重新连接桌面端。" : "先连接电脑上的 MiniDesk，再输入并发送提醒或随手记。")
                } actions: {
                    Button(store.needsPairing ? "重新配对" : "立即配对") { showPairing = true }
                        .buttonStyle(.glassProminent)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if store.isPaired { editingTools }
        }
        .background { DeskBackdrop() }
        .navigationTitle("MiniDesk").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if store.isPaired {
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
        }
        .onChange(of: store.isPaired) { _, paired in
            if !paired {
                editing = false
                showsSendSuccess = false
                showsPasteError = false
            }
        }
        .onChange(of: store.draft) { _, draft in
            if !draft.isEmpty {
                discardClearUndo()
                withAnimation(.easeOut(duration: 0.2)) { showsSendSuccess = false }
            }
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
        .task(id: clearUndoDeadline) {
            guard let deadline = clearUndoDeadline else { return }
            do {
                try await Task.sleep(for: .seconds(max(0, deadline.timeIntervalSinceNow)))
                discardClearUndo()
            } catch {}
        }
        .onDisappear {
            editing = false; showsSendSuccess = false; showsPasteError = false
            discardClearUndo()
        }
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
                    ZStack {
                        animatedTool(visible: !store.draft.isEmpty) {
                            Button(action: clearDraft) {
                                toolSurface(destructive: true) { Image(systemName: "trash") }
                            }.buttonStyle(.plain).allowsHitTesting(!store.busy)
                                .accessibilityLabel("清空草稿")
                        }
                        animatedTool(visible: clearedDraft != nil && store.draft.isEmpty) {
                            Button(action: restoreClearedDraft) {
                                toolSurface { Image(systemName: "arrow.uturn.backward") }
                            }.buttonStyle(.plain).allowsHitTesting(!store.busy)
                                .accessibilityLabel("撤销清空")
                                .accessibilityHint("恢复刚刚清空的文本")
                        }
                    }.frame(width: 58, height: 48)
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
                        Button(action: dismissKeyboard) {
                            toolSurface { Image(systemName: "keyboard.chevron.compact.down") }
                        }.buttonStyle(.plain).accessibilityLabel("收起键盘")
                    }
                }
            }
        }.padding(.horizontal, 20).padding(.vertical, 8)
    }
    private func animatedTool<Content: View>(visible: Bool, @ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(width: 58, height: 48)
            .opacity(visible ? 1 : 0)
            .allowsHitTesting(visible)
            .accessibilityHidden(!visible)
            .animation(.easeInOut(duration: reduceMotion ? 0.12 : 0.22), value: visible)
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
    private func clearDraft() {
        guard !store.busy, !store.draft.isEmpty else { return }
        clearedDraft = store.draft
        clearUndoDeadline = Date().addingTimeInterval(5)
        store.draft = ""
    }
    private func restoreClearedDraft() {
        guard !store.busy, store.draft.isEmpty,
              let deadline = clearUndoDeadline, deadline > Date(),
              let saved = clearedDraft else {
            discardClearUndo()
            return
        }
        discardClearUndo()
        store.draft = saved
    }
    private func discardClearUndo() {
        clearedDraft = nil
        clearUndoDeadline = nil
    }

    private func pasteDraft() {
        guard store.isPaired, !store.busy else { return }
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
    private func dismissKeyboard() {
        editing = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    private func sendDraft() {
        guard canSend else { return }
        dismissKeyboard()
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
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
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
    @State private var copiedAddress: String?
    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 38, weight: .light)).foregroundStyle(.tint)
                        .frame(width: 76, height: 76)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22))
                    Text("桌面已配对").font(.title2.bold())
                    Text("可发送提醒事项和随手记")
                        .font(.subheadline).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity).padding(.vertical, 16)
            }.listRowBackground(Color.clear)
            Section("配对管理") {
                if let code = store.code {
                    Button {
                        UIPasteboard.general.string = code
                        copiedAddress = nil
                        copyFeedbackID += 1
                    } label: {
                        HStack {
                            Text("配对码").foregroundStyle(.primary)
                            Spacer()
                            Text(Pairing.masked(code))
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Image(systemName: "doc.on.doc").font(.subheadline)
                        }
                    }.accessibilityHint("轻点复制完整配对码")
                }
                Button("更换配对", systemImage: "arrow.triangle.2.circlepath") {
                    showPairing = true
                }.disabled(store.busy)
                Button(role: .destructive) {
                    disconnect = true
                } label: {
                    Label("断开配对", systemImage: "xmark.circle")
                        .foregroundStyle(.red)
                }.tint(.red).disabled(store.busy)
            }
            Section {
                Button("复制桌面端地址", systemImage: "doc.on.clipboard") {
                    let address = "https://minidesk.online"
                    UIPasteboard.general.string = address
                    copiedAddress = address
                    copyFeedbackID += 1
                }
            } header: {
                Text("桌面端")
            } footer: {
                Text("在电脑浏览器打开 minidesk.online。")
            }
            Section {
                DisclosureGroup("数据与隐私") {
                    Text("配对码保存在本机钥匙串，草稿和历史记录保存在本机。消息通过 HTTPS 发送，中转服务可读取内容；开启 AI 润色后，内容会交给服务端模型处理。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }.navigationTitle("配对")
            .scrollIndicators(.hidden)
            .modifier(CopyFeedback(trigger: copyFeedbackID, detail: copiedAddress))
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
    var detail: String? = nil
    var body: some View {
        VStack(spacing: 5) {
            Label(text, systemImage: symbol)
                .font(.system(size: 14, weight: .semibold))
            if let detail {
                Text(detail).font(.system(size: 13, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
            }
        }
            .foregroundStyle(.white)
            .padding(.horizontal, 18).padding(.vertical, 12)
            .glassEffect(.regular.tint(Color.accentColor.opacity(0.7)), in: Capsule())
            .shadow(color: Color.accentColor.opacity(0.2), radius: 10, y: 3)
            .allowsHitTesting(false)
            .accessibilityAddTraits(.updatesFrequently)
    }
}

struct CopyFeedback: ViewModifier {
    let trigger: Int
    var detail: String? = nil
    @State private var visible = false
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if visible {
                    SuccessNotice(text: detail == nil ? "文本已复制到剪贴板" : "已复制到剪贴板", symbol: "checkmark.circle.fill", detail: detail)
                        .padding(.top, 8).transition(.opacity)
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: trigger)
            .onChange(of: trigger) { _, _ in
                // Only a new copy event may show the notice. A task also restarts
                // when this tab reappears, so it must never show an old notice.
                withAnimation(.easeInOut(duration: 0.2)) { visible = true }
            }
            .task(id: trigger) {
                guard trigger > 0 else { return }
                do {
                    try await Task.sleep(for: .seconds(2))
                    withAnimation(.easeInOut(duration: 0.2)) { visible = false }
                } catch {}
            }
            .onDisappear { visible = false }
    }
}

#Preview { RootView().environment(DeskStore()) }
