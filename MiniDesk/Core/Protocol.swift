import Foundation
import CryptoKit

public enum CaptureKind: String, Codable, CaseIterable, Sendable {
    case todo, note
    public var title: String { self == .todo ? "提醒事项" : "随手记" }
    public var symbol: String { self == .todo ? "checkmark.circle" : "note.text" }
}

public enum Pairing {
    public static func normalize(_ input: String) -> String {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let code: String
        if let url = URLComponents(string: value), let fragment = url.fragment, fragment.hasPrefix("inbox=") {
            code = String(fragment.dropFirst(6))
        } else { code = value }
        return code.filter { !$0.isWhitespace }.uppercased()
            .replacingOccurrences(of: "I", with: "1").replacingOccurrences(of: "L", with: "1")
            .replacingOccurrences(of: "O", with: "0")
    }
    public static func isValid(_ code: String) -> Bool {
        code.count == 12 && code.allSatisfy { "0123456789ABCDEFGHJKMNPQRSTVWXYZ".contains($0) }
    }
    public static func hash(_ code: String) -> String {
        SHA256.hash(data: Data(code.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    public static func masked(_ code: String) -> String { "\(code.prefix(4)) •••• \(code.suffix(4))" }
}

public struct CapturePayload: Codable, Sendable {
    public let kind: CaptureKind
    public let text: String
    public let createdAt: Int64
    public let polish: Bool
    public let tzOffsetMinutes: Int
    public init(kind: CaptureKind, text: String, polish: Bool, date: Date = .now, timeZone: TimeZone = .current) {
        self.kind = kind; self.text = text; self.polish = polish
        createdAt = Int64(date.timeIntervalSince1970 * 1000)
        tzOffsetMinutes = timeZone.secondsFromGMT(for: date) / 60
    }
}

public struct InboxRequest: Codable, Sendable {
    public let id: String
    public let payload: String
    public init(id: String, payload: CapturePayload) throws {
        self.id = id
        let encoder = JSONEncoder(); encoder.outputFormatting = [.withoutEscapingSlashes]
        self.payload = String(decoding: try encoder.encode(payload), as: UTF8.self)
    }
}

public enum RelayError: Error, LocalizedError, Equatable {
    case invalidCode, revoked, unknown, rateLimited, full, tooLarge, invalidRequest, server, network, malformed
    public var errorDescription: String? {
        switch self {
        case .invalidCode: "请输入桌面端显示的 12 位配对码。"
        case .revoked: "配对码已注销，请在桌面端获取新的配对码。"
        case .unknown: "配对码尚未注册，请先在桌面端打开手机速记配对。"
        case .rateLimited: "发送太频繁，请稍后重试。"
        case .full: "桌面收件箱已满，请打开桌面端接收后重试。"
        case .tooLarge: "内容太长，每行最多 500 个字符。"
        case .invalidRequest: "发送内容格式有误。"
        case .server: "中转服务暂时不可用，请稍后重试。"
        case .network: "无法连接中转服务，请检查网络后重试。"
        case .malformed: "中转服务返回了无法识别的数据。"
        }
    }
    public static func status(_ status: Int) -> RelayError {
        switch status { case 400: .invalidRequest; case 404: .unknown; case 410: .revoked
        case 429: .rateLimited; case 409: .full; case 413: .tooLarge; default: .server }
    }
}

public struct RelayClient: Sendable {
    public static let defaultURL = URL(string: "https://relay.minidesk.online:8443")!
    let baseURL: URL
    let session: URLSession
    public init(baseURL: URL = Self.defaultURL, session: URLSession = .shared) {
        self.baseURL = baseURL; self.session = session
    }
    private func endpoint(_ hash: String) -> URL { baseURL.appendingPathComponent("inbox").appendingPathComponent(hash) }
    public func check(hash: String) async throws {
        let data = try await perform(URLRequest(url: endpoint(hash).appendingPathComponent("status")))
        struct Status: Decodable { let status: String }
        guard let response = try? JSONDecoder().decode(Status.self, from: data) else { throw RelayError.malformed }
        switch response.status { case "active": return; case "revoked": throw RelayError.revoked
        case "unknown": throw RelayError.unknown; default: throw RelayError.malformed }
    }
    public func send(hash: String, item: InboxRequest) async throws {
        var request = URLRequest(url: endpoint(hash)); request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(item)
        _ = try await perform(request)
    }
    private func perform(_ request: URLRequest) async throws -> Data {
        var request = request; request.timeoutInterval = 15
        let result: (Data, URLResponse)
        do { result = try await session.data(for: request) } catch { throw RelayError.network }
        guard let response = result.1 as? HTTPURLResponse else { throw RelayError.malformed }
        guard (200..<300).contains(response.statusCode) else { throw RelayError.status(response.statusCode) }
        return result.0
    }
}

public enum DraftLines {
    public static func parse(_ text: String) throws -> [String] {
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        // Web's limit counts UTF-16 code units, not Swift grapheme clusters.
        guard lines.allSatisfy({ $0.utf16.count <= 500 }) else { throw RelayError.tooLarge }
        return lines
    }
}
