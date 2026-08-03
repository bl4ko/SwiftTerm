//
//  CaretSettleGateTests.swift
//

import XCTest

@testable import SwiftTerm

#if os(iOS) || os(visionOS) || os(macOS)

    final class CaretSettleGateTests: XCTestCase {
        func testFirstPositionCommitsImmediately() {
            var gate = CaretSettleGate(settleDelay: 0.05)
            XCTAssertEqual(gate.evaluate(row: 20, lastFeed: 1.0, now: 1.0), .commit)
        }

        func testSameRowCommitsDuringActiveStream() {
            var gate = CaretSettleGate(settleDelay: 0.05)
            _ = gate.evaluate(row: 20, lastFeed: 1.0, now: 1.0)
            // Typing at the prompt while output streams: row holds, bytes keep arriving.
            XCTAssertEqual(gate.evaluate(row: 20, lastFeed: 1.02, now: 1.02), .commit)
            XCTAssertEqual(gate.evaluate(row: 20, lastFeed: 1.04, now: 1.04), .commit)
        }

        func testRowChangeWaitsWhileStreamActive() {
            var gate = CaretSettleGate(settleDelay: 0.05)
            _ = gate.evaluate(row: 20, lastFeed: 1.0, now: 1.0)
            guard case .wait(let remaining) = gate.evaluate(row: 5, lastFeed: 1.03, now: 1.03) else {
                return XCTFail("mid-stream row change must wait")
            }
            XCTAssertEqual(remaining, 0.05, accuracy: 0.001)
        }

        func testRowChangeCommitsOnceStreamQuiet() {
            var gate = CaretSettleGate(settleDelay: 0.05)
            _ = gate.evaluate(row: 20, lastFeed: 1.0, now: 1.0)
            XCTAssertEqual(gate.evaluate(row: 5, lastFeed: 1.03, now: 1.09), .commit)
        }

        // tmux shows the cursor before parking it, and every redraw cycle parks the
        // walking cursor on the same cell. A stability-keyed gate committed that
        // recurring wrong cell; a quiescence-keyed gate must not.
        func testRecurringRepaintParkNeverCommitsWhileStreaming() {
            var gate = CaretSettleGate(settleDelay: 0.05)
            _ = gate.evaluate(row: 45, lastFeed: 1.0, now: 1.0)
            var t = 1.0
            for _ in 0..<20 {
                t += 0.03
                XCTAssertEqual(gate.evaluate(row: 12, lastFeed: t, now: t), .wait(0.05))
                t += 0.03
                XCTAssertEqual(gate.evaluate(row: 45, lastFeed: t, now: t), .commit)
            }
        }

        func testRowChangeCommitsImmediatelyWhenStreamIdle() {
            var gate = CaretSettleGate(settleDelay: 0.05)
            _ = gate.evaluate(row: 20, lastFeed: 1.0, now: 1.0)
            // The user scrolls or moves lines with no output arriving: follow at once.
            XCTAssertEqual(gate.evaluate(row: 35, lastFeed: 1.0, now: 5.0), .commit)
        }

        func testWaitReportsRemainingQuietTime() {
            var gate = CaretSettleGate(settleDelay: 0.05)
            _ = gate.evaluate(row: 20, lastFeed: 1.0, now: 1.0)
            guard case .wait(let remaining) = gate.evaluate(row: 5, lastFeed: 1.0, now: 1.02) else {
                return XCTFail("expected wait")
            }
            XCTAssertEqual(remaining, 0.03, accuracy: 0.001)
        }

        func testResetMakesTheNextEvaluationCommit() {
            var gate = CaretSettleGate(settleDelay: 0.05)
            _ = gate.evaluate(row: 20, lastFeed: 1.0, now: 1.0)
            gate.reset()
            XCTAssertEqual(gate.evaluate(row: 3, lastFeed: 1.01, now: 1.01), .commit)
        }
    }

#endif
