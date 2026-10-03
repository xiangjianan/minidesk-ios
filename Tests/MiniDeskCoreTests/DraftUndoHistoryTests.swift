import Testing
@testable import MiniDeskCore

@Test func undoPreservesEarlierCommittedChineseText() {
    var history = DraftUndoHistory(initial: "明天开会")
    history.record("明天开会，")
    history.record("明天开会，记得带电脑")
    #expect(history.undo() == "明天开会，")
    #expect(history.undo() == "明天开会")
    #expect(history.undo() == nil)
}

@Test func undoRestoresDeletedTextAndIgnoresRepeatedUpdates() {
    var history = DraftUndoHistory(initial: "买牛奶和面包")
    history.record("买牛奶")
    history.record("买牛奶")
    #expect(history.undo() == "买牛奶和面包")
    #expect(!history.canUndo)
}

@Test func clearingOrSendingRetiresOldUndoHistory() {
    var history = DraftUndoHistory()
    history.record("待发送内容")
    history.reset(to: "")
    #expect(history.undo() == nil)
    history.record("新的草稿")
    #expect(history.undo() == "")
    #expect(history.undo() == nil)
}
