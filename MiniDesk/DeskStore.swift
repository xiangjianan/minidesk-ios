import SwiftUI
import Observation

struct Delivery: Identifiable, Codable {
    let id: String
    let hash: String
    let payload: CapturePayload
    var accepted: Bool = false
    var error: String?
    var date: Date { Date(timeIntervalSince1970: Double(payload.createdAt) / 1000) }
}

@MainActor @Observable final class DeskStore {
    var code: String? = PairingKeychain.load()
    var draft: String { didSet { UserDefaults.standard.set(draft, forKey: "draft") } }
    var kind: CaptureKind = .todo
    var polish: Bool { didSet { UserDefaults.standard.set(polish, forKey: "polish") } }
    var records: [Delivery] = []
    var busy = false
    var message: String?
    var error: String?
    var needsPairing = false
    var isPaired: Bool { code != nil && !needsPairing }
    private let client = RelayClient()
    private let file: URL
    init() {
        draft = UserDefaults.standard.string(forKey: "draft") ?? ""
        polish = UserDefaults.standard.bool(forKey: "polish")
        file = URL.applicationSupportDirectory.appendingPathComponent("deliveries.json")
        if let data = try? Data(contentsOf: file), let saved = try? JSONDecoder().decode([Delivery].self, from: data) { records = saved }
        if let code, !Pairing.isValid(code) { self.code = nil }
        #if DEBUG && targetEnvironment(simulator)
        // In-memory fixtures for store screenshots; never included in device or Release builds.
        if let scene = ProcessInfo.processInfo.environment["MINIDESK_SCREENSHOT_SCENE"] {
            code = "7K3M9Q2R5T8V"
            polish = false
            kind = scene == "note" ? .note : .todo
            draft = scene == "note"
                ? "周末的小计划\n\n找一家安静的咖啡馆，读完手边的书。\n沿着河边走走，把路上想到的事记下来。\n\n回到电脑前，再慢慢整理。"
                : "明天上午十点整理读书笔记\n周五下班后去取快递\n周末给阳台的植物浇水"
            let date = Date(timeIntervalSince1970: 1_792_224_000)
            records = [
                Delivery(id: "screenshot-note", hash: Pairing.hash(code!), payload: CapturePayload(kind: .note, text: "灵感备忘\n把零散的想法先记下来，回到桌面再整理。", polish: false, date: date), accepted: true),
                Delivery(id: "screenshot-todo-1", hash: Pairing.hash(code!), payload: CapturePayload(kind: .todo, text: "明天上午十点整理读书笔记", polish: false, date: date.addingTimeInterval(-300)), accepted: true),
                Delivery(id: "screenshot-todo-2", hash: Pairing.hash(code!), payload: CapturePayload(kind: .todo, text: "周末给阳台的植物浇水", polish: false, date: date.addingTimeInterval(-600)), accepted: true)
            ]
        }
        #endif
    }
    private func persist() throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(records).write(to: file, options: [.atomic, .completeFileProtection])
    }
    func pair(_ input: String) async {
        guard !busy else { return }
        busy = true; defer { busy = false }; error = nil
        let normalized = Pairing.normalize(input)
        guard Pairing.isValid(normalized) else { error = RelayError.invalidCode.localizedDescription; return }
        do {
            try await client.check(hash: Pairing.hash(normalized))
            try PairingKeychain.save(normalized); code = normalized; needsPairing = false
            message = "桌面配对成功"
        } catch { self.error = error.localizedDescription }
    }
    func unpair() { PairingKeychain.clear(); code = nil; needsPairing = false }
    func send() async {
        guard !busy, isPaired, let code else { return }
        error = nil; message = nil
        let lines: [String]
        do { lines = try DraftLines.parse(draft, kind: kind) } catch { self.error = error.localizedDescription; return }
        guard !lines.isEmpty else { return }
        busy = true; defer { busy = false }
        let entries = lines.map { Delivery(id: UUID().uuidString, hash: Pairing.hash(code), payload: CapturePayload(kind: kind, text: $0, polish: polish)) }
        records.insert(contentsOf: entries.reversed(), at: 0)
        // Save IDs before networking so uncertain requests can be retried with the same ID.
        do { try persist() } catch {
            records.removeAll { record in entries.contains { $0.id == record.id } }
            self.error = "无法保存发送记录，草稿已保留。"; return
        }
        draft = ""
        var count = 0
        for entry in entries {
            if await deliver(entry.id) { count += 1 } else { break }
        }
        if count > 0 { message = "中转已接收 \(count) 条，桌面端将在下次同步时收取。" }
        UINotificationFeedbackGenerator().notificationOccurred(error == nil ? .success : .error)
    }
    private func deliver(_ id: String) async -> Bool {
        guard let entry = records.first(where: { $0.id == id }) else { return false }
        do {
            try await client.send(hash: entry.hash, item: InboxRequest(id: entry.id, payload: entry.payload))
            if let index = records.firstIndex(where: { $0.id == id }) { records[index].accepted = true; records[index].error = nil }
            do { try persist() } catch { self.error = "中转已接收，但本机记录保存失败。" }
            return true
        } catch {
            self.error = error.localizedDescription
            if let index = records.firstIndex(where: { $0.id == id }) { records[index].error = error.localizedDescription }
            if let failure = error as? RelayError, failure == .revoked || failure == .unknown { needsPairing = true }
            try? persist(); return false
        }
    }
    func retry(_ id: String) async {
        guard !busy, let code, let record = records.first(where: { $0.id == id }), record.hash == Pairing.hash(code) else { return }
        busy = true; defer { busy = false }; error = nil
        if await deliver(id) { message = "中转已接收，等待桌面同步。" }
    }
    func canRetry(_ record: Delivery) -> Bool { !record.accepted && code.map { Pairing.hash($0) == record.hash } == true }
    func discard(_ id: String) {
        let previous = records; records.removeAll { $0.id == id }
        do { try persist() } catch { records = previous; self.error = "无法删除记录，请稍后重试。" }
    }
    func clearAccepted() {
        let previous = records; records.removeAll { $0.accepted }
        do { try persist() } catch { records = previous; self.error = "无法清除记录，请稍后重试。" }
    }
}
