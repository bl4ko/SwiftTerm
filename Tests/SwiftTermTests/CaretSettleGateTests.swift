//
//  CaretSettleGateTests.swift
//

import XCTest

@testable import SwiftTerm

#if os(iOS) || os(visionOS) || os(macOS)

    final class CaretSettleGateTests: XCTestCase {
        func testFirstPositionCommitsImmediately() {
            var gate = CaretSettleGate()
            XCTAssertEqual(gate.evaluate(row: 40, now: 0), .commit)
        }

        func testMovesWithinCommittedRowCommitImmediately() {
            var gate = CaretSettleGate()
            _ = gate.evaluate(row: 40, now: 0)
            XCTAssertEqual(gate.evaluate(row: 40, now: 0.001), .commit)
            XCTAssertEqual(gate.evaluate(row: 40, now: 0.002), .commit)
        }

        func testRowChangeWaitsForTheRowToSettle() {
            var gate = CaretSettleGate(settleDelay: 0.12)
            _ = gate.evaluate(row: 40, now: 0)
            XCTAssertEqual(gate.evaluate(row: 12, now: 0), .wait(0.12))
            XCTAssertEqual(gate.evaluate(row: 12, now: 0.2), .commit)
        }

        // A repaint parks the cursor mid-screen for ~100ms before returning it to
        // the prompt. The caret must never follow it there.
        func testTransientRepaintPositionNeverCommits() {
            var gate = CaretSettleGate(settleDelay: 0.12)
            _ = gate.evaluate(row: 48, now: 0)
            guard case .wait = gate.evaluate(row: 12, now: 0.5) else {
                return XCTFail("a jump to another row must not commit at once")
            }
            guard case .wait = gate.evaluate(row: 12, now: 0.58) else {
                return XCTFail("the row has not settled yet")
            }
            XCTAssertEqual(gate.evaluate(row: 48, now: 0.6), .commit)
        }

        // Bulk output moves the cursor every frame; nothing settles, so nothing commits.
        func testContinuouslyChangingRowsNeverCommit() {
            var gate = CaretSettleGate(settleDelay: 0.12)
            _ = gate.evaluate(row: 0, now: 0)
            var now = 0.0
            for row in 1...50 {
                now += 0.02
                guard case .wait = gate.evaluate(row: row, now: now) else {
                    return XCTFail("row \(row) committed while output was still moving")
                }
            }
        }

        func testResetMakesTheNextEvaluationCommit() {
            var gate = CaretSettleGate(settleDelay: 0.12)
            _ = gate.evaluate(row: 40, now: 0)
            _ = gate.evaluate(row: 12, now: 0)
            gate.reset()
            XCTAssertEqual(gate.evaluate(row: 12, now: 0.01), .commit)
        }
    }

#endif
