import Foundation
import Testing
@testable import MiniDeskCore

@Test func pairingNormalization() {
    #expect(Pairing.normalize(" abcd efgh 2345 \n") == "ABCDEFGH2345")
    #expect(Pairing.normalize("https://minidesk.online/#inbox=ABCDEFGH2345") == "ABCDEFGH2345")
    #expect(Pairing.normalize("minidesk://pair#inbox=ABCDEFGH2345") == "ABCDEFGH2345")
    #expect(Pairing.normalize("ilo1 2345 6789") == "110123456789")
    #expect(Pairing.isValid("ABCDEFGH2345"))
    #expect(!Pairing.isValid("ABCDEFGU2345"))
    #expect(!Pairing.isValid("short"))
}
@Test func hashMatchesWebCrypto() {
    #expect(Pairing.hash("ABCDEFGH2345") == "77485ffa630b96946173a2d8ecff374327af1d230aafd5f8c18ddf9177441900")
}
@Test func wirePayloadMatchesDesktop() throws {
    let payload = CapturePayload(kind: .todo, text: "明天买花", polish: false, date: Date(timeIntervalSince1970: 1000), timeZone: TimeZone(secondsFromGMT: 28800)!)
    let request = try InboxRequest(id: "same-id-on-retry", payload: payload)
    let data = try JSONEncoder().encode(request)
    let outer = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])
    #expect(outer["id"] == "same-id-on-retry")
    let payloadString = try #require(outer["payload"])
    let inner = try #require(JSONSerialization.jsonObject(with: Data(payloadString.utf8)) as? [String: Any])
    #expect(inner["kind"] as? String == "todo")
    #expect(inner["text"] as? String == "明天买花")
    #expect(inner["createdAt"] as? Int == 1_000_000)
    #expect(inner["polish"] as? Bool == false)
    #expect(inner["tzOffsetMinutes"] as? Int == 480)
}
@Test func linesAreNotSilentlyTruncated() throws {
    #expect(try DraftLines.parse(" 一条\r\n\n 二条 \n") == ["一条", "二条"])
    #expect(throws: RelayError.tooLarge) { try DraftLines.parse(String(repeating: "😀", count: 251)) }
    #expect(try DraftLines.parse(String(repeating: "a", count: 500)).first?.count == 500)
}
@Test func errorsMatchRelayStatuses() {
    #expect(RelayError.status(404) == .unknown)
    #expect(RelayError.status(410) == .revoked)
    #expect(RelayError.status(429) == .rateLimited)
    #expect(RelayError.status(409) == .full)
    #expect(RelayError.status(413) == .tooLarge)
}
