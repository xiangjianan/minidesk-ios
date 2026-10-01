import Foundation
import Testing
@testable import MiniDeskCore

private final class RelayStub: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let url = request.url!
        let status: Int
        let body: String
        if url.path.hasSuffix("/status") {
            #expect(request.httpMethod == "GET")
            status = 200
            if url.path.contains("revoked") { body = "{\"status\":\"revoked\"}" }
            else if url.path.contains("unknown") { body = "{\"status\":\"unknown\"}" }
            else if url.path.contains("malformed") { body = "{}" }
            else { body = "{\"status\":\"active\"}" }
        } else {
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            #expect(request.value(forHTTPHeaderField: "Origin") == nil)
            #expect(request.timeoutInterval == 15)
            var data = request.httpBody ?? Data()
            if data.isEmpty, let stream = request.httpBodyStream {
                stream.open(); defer { stream.close() }
                var buffer = [UInt8](repeating: 0, count: 1024)
                while stream.hasBytesAvailable { let n = stream.read(&buffer, maxLength: buffer.count); if n <= 0 { break }; data.append(contentsOf: buffer.prefix(n)) }
            }
            let parsed = try? JSONDecoder().decode(InboxRequest.self, from: data)
            #expect(parsed?.id == "stable-id")
            #expect(parsed?.payload.contains("todo") == true)
            status = url.path.contains("full") ? 409 : 200; body = "{\"ok\":true}"
        }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8)); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private func stubClient() -> RelayClient {
    let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [RelayStub.self]
    return RelayClient(baseURL: URL(string: "https://relay.example")!, session: URLSession(configuration: config))
}

@Test func pairingChecksActiveBeforeAccepting() async throws { try await stubClient().check(hash: "active") }
@Test(arguments: [("revoked", RelayError.revoked), ("unknown", .unknown), ("malformed", .malformed)])
func pairingRejectsUnusableCodes(input: (String, RelayError)) async {
    do { try await stubClient().check(hash: input.0); Issue.record("Expected pairing failure") }
    catch { #expect(error as? RelayError == input.1) }
}
@Test func senderUsesExistingWireContractAndStableIDs() async throws {
    let client = stubClient()
    let request = try InboxRequest(id: "stable-id", payload: CapturePayload(kind: .todo, text: "买花", polish: false))
    try await client.send(hash: "active", item: request)
    try await client.send(hash: "active", item: request)
}
@Test func senderHandlesQueueFull() async throws {
    let request = try InboxRequest(id: "stable-id", payload: CapturePayload(kind: .todo, text: "买花", polish: false))
    do { try await stubClient().send(hash: "full", item: request); Issue.record("Expected queue full") }
    catch { #expect(error as? RelayError == .full) }
}
