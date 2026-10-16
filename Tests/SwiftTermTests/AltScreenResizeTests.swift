import Testing

@testable import SwiftTerm

final class AltScreenResizeTests {
    @Test func shrinkingAltScreenKeepsTopRows() {
        let (t, _) = TerminalTestHarness.makeTerminal(cols: 20, rows: 10, scrollback: 100)
        t.feed(text: "\u{1b}[?1049h\u{1b}[1;1HHEADER\u{1b}[10;1HPROMPT")

        t.resize(cols: 20, rows: 6)

        #expect(TerminalTestHarness.lineText(buffer: t.buffer, row: 0) == "HEADER")
        #expect(t.buffer.y == 5)
    }

    @Test func shrinkingNormalScreenKeepsCursorRow() {
        let (t, _) = TerminalTestHarness.makeTerminal(cols: 20, rows: 10, scrollback: 100)
        t.feed(text: "\u{1b}[1;1HHEADER\u{1b}[10;1HPROMPT")

        t.resize(cols: 20, rows: 6)

        #expect(TerminalTestHarness.lineText(buffer: t.buffer, row: 5) == "PROMPT")
    }
}
