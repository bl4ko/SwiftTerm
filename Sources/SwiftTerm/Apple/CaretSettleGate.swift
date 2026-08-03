//
//  CaretSettleGate.swift
//
//  Decides when the caret may follow the terminal cursor.
//
//  tmux redraws show the cursor (CSI ?25h) *before* parking it at its final
//  position, so a read boundary inside that window leaves the buffer cursor
//  visible mid-screen until the rest of the burst arrives. Keying on row
//  stability cannot fix this: every scroll moves the true cursor's absolute
//  row, while each redraw parks the walking cursor on the same cell, so the
//  wrong position is the one that looks stable. Instead the gate keys on the
//  viewport row and on stream quiescence: a caret that kept its viewport row
//  follows immediately (typing stays live), and a row change only commits
//  once no bytes have arrived for `settleDelay` - a screen nothing is writing
//  to is a finished screen.
//

import Foundation

struct CaretSettleGate {
    enum Decision: Equatable {
        case commit
        case wait(TimeInterval)
    }

    /// How long the input stream must stay quiet before a row change commits.
    var settleDelay: TimeInterval

    private var committedRow: Int?

    init(settleDelay: TimeInterval = 0.05) {
        self.settleDelay = settleDelay
    }

    /// Called for every cursor update. `row` is the viewport-relative cursor row,
    /// `lastFeed` the time the last input bytes arrived.
    mutating func evaluate(row: Int, lastFeed: TimeInterval, now: TimeInterval) -> Decision {
        if committedRow == nil || row == committedRow {
            committedRow = row
            return .commit
        }
        let idle = now - lastFeed
        if idle >= settleDelay {
            committedRow = row
            return .commit
        }
        return .wait(settleDelay - idle)
    }

    /// Drops the committed row, so the next evaluation commits immediately.
    mutating func reset() {
        committedRow = nil
    }
}
