//
//  CaretSettleGate.swift
//
//  Decides when the caret may follow the terminal cursor.
//
//  A repaint walks the cursor across the screen before parking it at its final
//  spot. When the repaint arrives split across reads - routine over SSH, where a
//  burst straddles TCP segments - the terminal paints a half-finished frame and
//  the caret would otherwise render wherever the paint happened to be, for as
//  long as the rest takes to arrive. The caret only belongs on a settled screen,
//  so a move to a different row has to hold that row briefly before it commits;
//  moves within the committed row (typed characters) commit at once.
//

import Foundation

struct CaretSettleGate {
    enum Decision: Equatable {
        case commit
        case wait(TimeInterval)
    }

    /// How long a new row must persist before the caret follows it.
    var settleDelay: TimeInterval

    private var committedRow: Int?
    private var pendingRow: Int?
    private var pendingSince: TimeInterval = 0

    init(settleDelay: TimeInterval = 0.12) {
        self.settleDelay = settleDelay
    }

    /// Called for every cursor update. `row` is the absolute buffer row.
    mutating func evaluate(row: Int, now: TimeInterval) -> Decision {
        if committedRow == nil || row == committedRow {
            committedRow = row
            pendingRow = nil
            return .commit
        }
        if pendingRow != row {
            pendingRow = row
            pendingSince = now
        }
        let waited = now - pendingSince
        if waited >= settleDelay {
            committedRow = row
            pendingRow = nil
            return .commit
        }
        return .wait(settleDelay - waited)
    }

    /// Drops any pending row, so the next evaluation commits immediately.
    mutating func reset() {
        committedRow = nil
        pendingRow = nil
    }
}
