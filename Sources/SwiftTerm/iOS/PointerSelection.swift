//
//  PointerSelection.swift
//
// Public entry points for pointer-driven (mouse/trackpad) selection, used by
// Mac Catalyst hosts where drag gestures come from a pointer rather than touch.
//
#if os(iOS) || os(visionOS)
import UIKit

extension TerminalView {
    /// Anchors an empty selection at the given point, ready to be extended.
    /// A rectangular selection covers only the columns between its corners,
    /// which is how text is pulled out of one column of a split screen.
    public func startPointerSelection (at point: CGPoint, rectangular: Bool = false) {
        let hit = calculateTapHit(point: point).grid
        selection.setSoftStart(bufferPosition: hit)
        // pivotExtend is a no-op without a pivot, and setSoftStart leaves it nil.
        selection.pivot = hit
        selection.rectangular = rectangular || selection.hasVisibleVerticalDivider()
    }

    /// Extends the pointer selection to the given point, activating it if
    /// needed. Includes both the anchor cell and the cell under the pointer;
    /// raw pivotExtend drops the anchor character on backward drags.
    public func extendPointerSelection (to point: CGPoint) {
        guard let pivot = selection.pivot else { return }
        let hit = calculateTapHit(point: point).grid
        let span = PointerSelectionMath.span (pivot: pivot, hit: hit, cols: terminal.cols)
        selection.setSelection (start: span.start, end: span.end)
        enableSelectionPanGesture()
        queuePendingDisplay()
    }

    /// Selects the word or expression at the given point.
    public func selectWord (at point: CGPoint) {
        let hit = calculateTapHit(point: point).grid
        selection.selectWordOrExpression(at: hit, in: terminal.displayBuffer)
        selection.selectionMode = .character
        selection.pivot = selection.start
        enableSelectionPanGesture()
        queuePendingDisplay()
    }

    /// Selects the whole row at the given point.
    public func selectRow (at point: CGPoint) {
        let hit = calculateTapHit(point: point).grid
        selection.select(row: hit.row)
        selection.pivot = selection.start
        enableSelectionPanGesture()
        queuePendingDisplay()
    }

    /// True while SwiftTerm's own selection pan gesture is armed, which happens
    /// once a selection is made by touch. Hosts that install their own pan
    /// gesture use this to yield the drag to selection adjustment.
    public var selectionPanActive: Bool {
        panSelectionGesture != nil
    }

    /// Arms a selection-handle drag when `point` falls on one of the handles
    /// of the active selection. The selection itself is left untouched until
    /// the drag moves; the touch-to-handle offset is remembered so the edge
    /// tracks the finger relative to where it was grabbed.
    @discardableResult
    public func grabSelectionHandle (at point: CGPoint, slop: CGFloat = 30) -> Bool {
        guard selection.active else {
            selectionHandleGrabState = nil
            return false
        }
        let (first, last) = Position.compare (selection.start, selection.end) == .after
            ? (selection.end, selection.start)
            : (selection.start, selection.end)
        guard let grab = SelectionHandleMath.grab (point: point, start: first, end: last,
                                                   cellWidth: cellDimension.width,
                                                   cellHeight: cellDimension.height,
                                                   slop: slop)
        else {
            selectionHandleGrabState = nil
            return false
        }
        selection.pivot = grab.handle == .start ? last : first
        selectionHandleGrabState = grab
        return true
    }

    /// True from a successful `grabSelectionHandle` until `endSelectionHandleDrag`.
    public var selectionHandleDragActive: Bool {
        selectionHandleGrabState != nil
    }

    /// Moves the grabbed selection handle, keeping the grab offset.
    public func dragSelectionHandle (to point: CGPoint) {
        guard let grab = selectionHandleGrabState, selection.active else { return }
        let hit = calculateTapHit (point: point).grid
        let target = Position (col: min (max (0, hit.col + grab.colOffset), terminal.cols - 1),
                               row: max (0, hit.row + grab.rowOffset))
        selection.pivotExtend (bufferPosition: target)
        queuePendingDisplay()
    }

    /// Ends a selection-handle drag.
    public func endSelectionHandleDrag () {
        selectionHandleGrabState = nil
    }

    /// Clears any active selection.
    public func clearSelection () {
        selection.selectNone()
        endSelectionHandleDrag()
        disableSelectionPanGesture()
        queuePendingDisplay()
    }

    /// Disables system inline predictions, which otherwise install a marked-text
    /// range that swallows the first hardware key press after certain characters.
    @available(iOS 17.0, macCatalyst 17.0, *)
    public var inlinePredictionType: UITextInlinePredictionType {
        get { .no }
        set { }
    }
}
#endif
