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
        selection.rectangular = rectangular
    }

    /// Extends the pointer selection to the given point, activating it if needed.
    public func extendPointerSelection (to point: CGPoint) {
        let hit = calculateTapHit(point: point).grid
        selection.pivotExtend(bufferPosition: hit)
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

    /// Clears any active selection.
    public func clearSelection () {
        selection.selectNone()
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
