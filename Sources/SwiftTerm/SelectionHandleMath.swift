//
//  SelectionHandleMath.swift
//
// Pure hit-testing for touch-driven selection handle drags: decides whether a
// touch grabs the start or end handle, and records the cell offset between the
// touch and the handle so a drag moves the handle relative to where it was
// grabbed instead of snapping the selection edge to the finger.
//
import Foundation
import CoreGraphics

public struct SelectionHandleGrab: Equatable {
    public enum Handle: Equatable {
        case start
        case end
    }
    public let handle: Handle
    public let colOffset: Int
    public let rowOffset: Int

    public init (handle: Handle, colOffset: Int, rowOffset: Int) {
        self.handle = handle
        self.colOffset = colOffset
        self.rowOffset = rowOffset
    }
}

public enum SelectionHandleMath {
    /// Returns the handle grabbed by a touch at `point`, or nil when the touch
    /// is not close enough to either handle.
    ///
    /// - Parameters:
    ///  - point: touch location in content coordinates (the space where row 0
    ///    starts at y == 0 and each row is `cellHeight` tall)
    ///  - start: normalized selection start (start <= end), buffer-relative
    ///  - end: normalized selection end, buffer-relative
    ///  - slop: maximum distance in points from the handle anchor
    public static func grab (point: CGPoint, start: Position, end: Position,
                             cellWidth: CGFloat, cellHeight: CGFloat,
                             slop: CGFloat = 30) -> SelectionHandleGrab?
    {
        guard cellWidth > 0, cellHeight > 0 else { return nil }
        // The start handle hangs below the start cell, the end handle sits on
        // top of the end cell, mirroring how drawSelectionHandle places them.
        let startAnchor = CGPoint (x: CGFloat (start.col) * cellWidth,
                                   y: CGFloat (start.row + 1) * cellHeight)
        let endAnchor = CGPoint (x: CGFloat (end.col) * cellWidth,
                                 y: CGFloat (end.row) * cellHeight)
        let startDistance = hypot (point.x - startAnchor.x, point.y - startAnchor.y)
        let endDistance = hypot (point.x - endAnchor.x, point.y - endAnchor.y)
        guard min (startDistance, endDistance) <= slop else { return nil }

        let hitCol = Int (point.x / cellWidth)
        let hitRow = Int (point.y / cellHeight)
        if startDistance <= endDistance {
            return SelectionHandleGrab (handle: .start,
                                        colOffset: start.col - hitCol,
                                        rowOffset: start.row - hitRow)
        }
        return SelectionHandleGrab (handle: .end,
                                    colOffset: end.col - hitCol,
                                    rowOffset: end.row - hitRow)
    }
}
