//
//  CaretSettleGate.swift
//
//  Decides when the caret may follow the terminal cursor.
//
//  A TUI under load writes its repaint in pieces with pauses between them, and
//  the cursor is legitimately visible mid-screen between the pieces - tmux
//  relays the pane cursor honestly, so the protocol alone cannot distinguish a
//  half-finished frame from a finished one. The reliable tell is *how* the
//  cursor got where it is: a finished frame parks the cursor with explicit
//  addressing (CUP), while a mid-frame piece leaves it wherever text output,
//  newlines, or erases dragged it. The gate therefore commits a row change
//  immediately when the position was explicitly addressed, and otherwise only
//  after the stream has been quiet long enough to rule out a mid-frame pause.
//  Cursor hides use the same quiet-time rule because multiplexers hide the
//  client cursor while repainting panes, then restore it with the final park.
//  Moves within the committed row (typing) always commit at once.
//

import Foundation

struct CaretSettleGate {
    enum Decision: Equatable {
        case commit
        case wait(TimeInterval)
    }

    /// Quiet time required before an unaddressed row change commits.
    var settleDelay: TimeInterval

    private var committedRow: Int?
    private var committedHidden = false

    init(settleDelay: TimeInterval = 0.25) {
        self.settleDelay = settleDelay
    }

    /// Called for every cursor update. `row` is the viewport-relative cursor row,
    /// `addressed` whether the position came from explicit cursor addressing,
    /// `hidden` whether the terminal currently requests a hidden cursor,
    /// `lastFeed` the time the last input bytes arrived.
    mutating func evaluate(
        row: Int, addressed: Bool, hidden: Bool = false, lastFeed: TimeInterval, now: TimeInterval
    ) -> Decision {
        if hidden != committedHidden {
            let quietTime = now - lastFeed
            if hidden && quietTime < settleDelay {
                return .wait(settleDelay - quietTime)
            }
            committedHidden = hidden
        }
        if hidden {
            return .commit
        }
        if addressed || row == committedRow || now - lastFeed >= settleDelay {
            committedRow = row
            return .commit
        }
        return .wait(settleDelay - (now - lastFeed))
    }

    /// Drops the committed row, so the next position must settle again.
    mutating func reset() {
        committedRow = nil
        committedHidden = false
    }
}
