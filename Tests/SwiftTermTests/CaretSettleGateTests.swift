//
//  CaretSettleGateTests.swift
//

import XCTest

@testable import SwiftTerm

#if os(iOS) || os(visionOS) || os(macOS)

    final class CaretSettleGateTests: XCTestCase {
        func testFirstUnaddressedPositionMustSettle() {
            var gate = CaretSettleGate(settleDelay: 0.25)
            XCTAssertEqual(gate.evaluate(row: 20, addressed: false, lastFeed: 1.0, now: 1.0), .wait(0.25))
            XCTAssertEqual(gate.evaluate(row: 20, addressed: false, lastFeed: 1.0, now: 1.25), .commit)
        }

        func testSameRowCommitsDuringActiveStream() {
            var gate = CaretSettleGate(settleDelay: 0.25)
            _ = gate.evaluate(row: 20, addressed: true, lastFeed: 1.0, now: 1.0)
            // Typing at the prompt while output streams: row holds, bytes keep arriving.
            XCTAssertEqual(gate.evaluate(row: 20, addressed: false, lastFeed: 1.02, now: 1.02), .commit)
            XCTAssertEqual(gate.evaluate(row: 20, addressed: false, lastFeed: 1.04, now: 1.04), .commit)
        }

        func testAddressedRowChangeCommitsImmediately() {
            // A finished redraw parks the cursor with CUP: follow at once, even
            // while bytes are still arriving.
            var gate = CaretSettleGate(settleDelay: 0.25)
            _ = gate.evaluate(row: 20, addressed: true, lastFeed: 1.0, now: 1.0)
            XCTAssertEqual(gate.evaluate(row: 45, addressed: true, lastFeed: 1.01, now: 1.01), .commit)
        }

        func testHideWaitsForQuietButShowCommitsImmediately() {
            var gate = CaretSettleGate(settleDelay: 0.25)
            _ = gate.evaluate(row: 20, addressed: true, lastFeed: 1.0, now: 1.0)
            XCTAssertEqual(
                gate.evaluate(row: 20, addressed: true, hidden: true, lastFeed: 1.01, now: 1.01),
                .wait(0.25))
            XCTAssertEqual(
                gate.evaluate(row: 20, addressed: true, hidden: true, lastFeed: 1.01, now: 1.26),
                .commit)
            XCTAssertEqual(
                gate.evaluate(row: 20, addressed: true, hidden: false, lastFeed: 1.27, now: 1.27),
                .commit)
        }

        // A busy TUI writes its repaint in pieces: the mid-frame piece leaves the
        // cursor dragged mid-screen by text and newlines, visible, for ~100ms.
        // Unaddressed row changes must wait out the pause.
        func testMidFramePieceNeverCommitsDuringPause() {
            var gate = CaretSettleGate(settleDelay: 0.25)
            _ = gate.evaluate(row: 40, addressed: true, lastFeed: 1.0, now: 1.0)
            var t = 1.0
            for _ in 0..<20 {
                t += 0.1
                guard case .wait = gate.evaluate(row: 29, addressed: false, lastFeed: t, now: t) else {
                    return XCTFail("mid-frame park must not commit while the stream is active")
                }
                t += 0.1
                XCTAssertEqual(gate.evaluate(row: 40, addressed: true, lastFeed: t, now: t), .commit)
            }
        }

        func testUnaddressedRowChangeCommitsOnceStreamQuiet() {
            // Plain shell Enter: "\r\n" + prompt text, no CUP. Commits after quiet.
            var gate = CaretSettleGate(settleDelay: 0.25)
            _ = gate.evaluate(row: 20, addressed: true, lastFeed: 1.0, now: 1.0)
            XCTAssertEqual(gate.evaluate(row: 21, addressed: false, lastFeed: 1.01, now: 1.30), .commit)
        }

        func testWaitReportsRemainingQuietTime() {
            var gate = CaretSettleGate(settleDelay: 0.25)
            _ = gate.evaluate(row: 20, addressed: true, lastFeed: 1.0, now: 1.0)
            guard case .wait(let remaining) = gate.evaluate(row: 5, addressed: false, lastFeed: 1.0, now: 1.1) else {
                return XCTFail("expected wait")
            }
            XCTAssertEqual(remaining, 0.15, accuracy: 0.001)
        }

        func testResetMakesTheNextEvaluationSettle() {
            var gate = CaretSettleGate(settleDelay: 0.25)
            _ = gate.evaluate(row: 20, addressed: true, lastFeed: 1.0, now: 1.0)
            gate.reset()
            XCTAssertEqual(gate.evaluate(row: 3, addressed: false, lastFeed: 1.01, now: 1.01), .wait(0.25))
        }
    }

#endif
