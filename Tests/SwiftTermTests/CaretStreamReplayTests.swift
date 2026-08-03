//
//  CaretStreamReplayTests.swift
//
//  Replays a captured tmux-over-ssh client stream through the emulator and the
//  caret gate. The bundled capture is a busy TUI writing each repaint in two
//  pieces with an ~80ms pause and the cursor left visible mid-frame - the
//  workload that made the caret blink mid-screen. The gate must suppress every
//  one of those mid-frame parks.
//
import Foundation
import XCTest

@testable import SwiftTerm

final class CaretStreamReplayTests: XCTestCase {
    class Delegate: TerminalDelegate {
        func send(source: Terminal, data: ArraySlice<UInt8>) {}
        func showCursor(source: Terminal) {}
        func hideCursor(source: Terminal) {}
    }

    struct Replay {
        var chunks = 0
        var exposures = 0
        var suppressed = 0
        var blips: [String] = []
    }

    /// Chunks are separated by `\n@@<timestamp>@@` markers written by the capture tool.
    static func parse(_ raw: [UInt8]) -> [(Double, [UInt8])] {
        var chunks: [(Double, [UInt8])] = []
        let marker = Array("\n@@".utf8)
        var i = 0
        var current: [UInt8] = []
        var currentTs = 0.0
        while i < raw.count {
            if i + 2 < raw.count, raw[i] == marker[0], raw[i + 1] == marker[1], raw[i + 2] == marker[2] {
                var j = i + 3
                var ts = ""
                while j < raw.count, raw[j] != UInt8(ascii: "@") {
                    ts.append(Character(UnicodeScalar(raw[j])))
                    j += 1
                }
                if !current.isEmpty { chunks.append((currentTs, current)) }
                current = []
                currentTs = Double(ts) ?? 0
                i = j + 2
            } else {
                current.append(raw[i])
                i += 1
            }
        }
        if !current.isEmpty { chunks.append((currentTs, current)) }
        return chunks
    }

    static func replay(_ raw: [UInt8]) -> Replay {
        let term = Terminal(delegate: Delegate(), options: TerminalOptions(cols: 200, rows: 50))
        var gate = CaretSettleGate()
        var result = Replay()
        var lastRow = -1
        let feed = parse(raw)
        result.chunks = feed.count
        for (idx, (ts, data)) in feed.enumerated() {
            term.feed(buffer: data[...])
            let row = term.buffer.y
            let visible = !term.cursorHidden
            let gap = idx + 1 < feed.count ? feed[idx + 1].0 - ts : 10
            guard visible else { continue }
            if row != lastRow && lastRow >= 0 {
                result.exposures += 1
                switch gate.evaluate(row: row, addressed: term.cursorAddressed, lastFeed: ts, now: ts) {
                case .commit:
                    // Unaddressed row jumps that get corrected shortly after are
                    // mid-frame states the user would see as a caret blip.
                    if !term.cursorAddressed && gap < 0.5 {
                        result.blips.append("t=\(ts) row \(lastRow)->\(row) gap=\(Int(gap * 1000))ms")
                    }
                case .wait(let remaining):
                    // A stream that stays quiet for over a second has genuinely
                    // stalled; revealing the cursor then is correct, not a blip.
                    if gap > remaining && gap < 1.0 {
                        result.blips.append("t=\(ts) timer-commit row \(row) gap=\(Int(gap * 1000))ms")
                    } else {
                        result.suppressed += 1
                    }
                }
            } else {
                _ = gate.evaluate(row: row, addressed: term.cursorAddressed, lastFeed: ts, now: ts)
            }
            lastRow = row
        }
        return result
    }

    func testBusyTuiMidFrameParksNeverPaintTheCaret() throws {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "busy-tui-client-stream", withExtension: "raw", subdirectory: "Resources"))
        let result = Self.replay([UInt8](try Data(contentsOf: url)))
        XCTAssertGreaterThan(result.exposures, 50, "capture no longer triggers mid-frame cursor exposure")
        XCTAssertGreaterThan(result.suppressed, 10, "gate no longer exercising the wait path")
        XCTAssertEqual(result.blips, [], "gate committed a mid-frame cursor position")
    }

    func testAdHocCapture() throws {
        guard let path = ProcessInfo.processInfo.environment["CAPTURE"] else {
            throw XCTSkip("set CAPTURE=/path/to/capture.raw to replay one")
        }
        let result = Self.replay([UInt8](try Data(contentsOf: URL(fileURLWithPath: path))))
        print("chunks=\(result.chunks) exposures=\(result.exposures) suppressed=\(result.suppressed)")
        result.blips.forEach { print("BLIP \($0)") }
        XCTAssertEqual(result.blips, [])
    }
}
