/// Tracks committed edits independently of UIKit's potentially session-wide groups.
public struct DraftUndoHistory {
    public private(set) var current: String
    private var previous: [String] = []
    public var canUndo: Bool { !previous.isEmpty }
    public init(initial: String = "") { current = initial }
    public mutating func reset(to text: String) { current = text; previous.removeAll() }
    public mutating func record(_ text: String) {
        guard text != current else { return }
        previous.append(current)
        if previous.count > 100 { previous.removeFirst() }
        current = text
    }
    public mutating func undo() -> String? {
        guard let text = previous.popLast() else { return nil }
        current = text
        return text
    }
}
