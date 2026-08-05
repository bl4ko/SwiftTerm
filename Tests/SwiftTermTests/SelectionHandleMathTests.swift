import XCTest
@testable import SwiftTerm

final class SelectionHandleMathTests: XCTestCase {
    let cw: CGFloat = 10
    let ch: CGFloat = 20
    let start = Position(col: 5, row: 3)
    let end = Position(col: 12, row: 3)

    func grab (_ point: CGPoint, slop: CGFloat = 30) -> SelectionHandleGrab? {
        SelectionHandleMath.grab(point: point, start: start, end: end,
                                 cellWidth: cw, cellHeight: ch, slop: slop)
    }

    func testGrabsStartHandleWithOffset () {
        // The start handle is drawn above the start cell, so its anchor is the
        // cell top (50, 60); a fat finger a cell right and above still grabs
        // it, and the offset points back at the true start cell.
        let hit = grab(CGPoint(x: 62, y: 45))
        XCTAssertEqual(hit, SelectionHandleGrab(handle: .start, colOffset: -1, rowOffset: 1))
    }

    func testGrabsEndHandleWithOffset () {
        // The end handle hangs below the end cell, anchor (120, 80); touching
        // just below-right of it lands one row down.
        let hit = grab(CGPoint(x: 128, y: 95))
        XCTAssertEqual(hit, SelectionHandleGrab(handle: .end, colOffset: 0, rowOffset: -1))
    }

    func testGrabInsideStartCellHasZeroOffset () {
        let hit = grab(CGPoint(x: 55, y: 65))
        XCTAssertEqual(hit, SelectionHandleGrab(handle: .start, colOffset: 0, rowOffset: 0))
    }

    func testGrabOnEndAnchorCompensatesBackToEndCell () {
        // The end anchor (120, 80) lies on the row boundary below the end
        // cell; the offset must point the drag back at the real end row.
        let hit = grab(CGPoint(x: 120, y: 80))
        XCTAssertEqual(hit, SelectionHandleGrab(handle: .end, colOffset: 0, rowOffset: -1))
    }

    func testFarTouchGrabsNothing () {
        XCTAssertNil(grab(CGPoint(x: 200, y: 300)))
        XCTAssertNil(grab(CGPoint(x: 85, y: 70), slop: 10))
    }

    func testNearestHandleWins () {
        let hit = grab(CGPoint(x: 110, y: 78), slop: 60)
        XCTAssertEqual(hit?.handle, .end)
    }

    func testCatalystSlopReachesDrawnHandles () {
        // The tight Catalyst slop (14) must still grab a click on the drawn
        // handle circles: 6 points above the start cell top and 6 below the
        // end cell bottom.
        XCTAssertEqual(grab(CGPoint(x: 50, y: 54), slop: 14)?.handle, .start)
        XCTAssertEqual(grab(CGPoint(x: 120, y: 86), slop: 14)?.handle, .end)
    }

    func testDegenerateCellSizeGrabsNothing () {
        XCTAssertNil(SelectionHandleMath.grab(point: .zero, start: start, end: end,
                                              cellWidth: 0, cellHeight: 0))
    }
}

final class PointerSelectionMathTests: XCTestCase {
    let cols = 80

    func testForwardDragIncludesCellUnderPointer () {
        let span = PointerSelectionMath.span(pivot: Position(col: 5, row: 3),
                                             hit: Position(col: 9, row: 3), cols: cols)
        XCTAssertEqual(span.start, Position(col: 5, row: 3))
        XCTAssertEqual(span.end, Position(col: 10, row: 3))
    }

    func testBackwardDragIncludesAnchorCell () {
        let span = PointerSelectionMath.span(pivot: Position(col: 9, row: 3),
                                             hit: Position(col: 5, row: 3), cols: cols)
        XCTAssertEqual(span.start, Position(col: 5, row: 3))
        XCTAssertEqual(span.end, Position(col: 10, row: 3))
    }

    func testDragWithinAnchorCellSelectsIt () {
        let span = PointerSelectionMath.span(pivot: Position(col: 5, row: 3),
                                             hit: Position(col: 5, row: 3), cols: cols)
        XCTAssertEqual(span.start, Position(col: 5, row: 3))
        XCTAssertEqual(span.end, Position(col: 6, row: 3))
    }

    func testBackwardMultiRowDragIncludesAnchorCell () {
        let span = PointerSelectionMath.span(pivot: Position(col: 4, row: 6),
                                             hit: Position(col: 20, row: 2), cols: cols)
        XCTAssertEqual(span.start, Position(col: 20, row: 2))
        XCTAssertEqual(span.end, Position(col: 5, row: 6))
    }

    func testLastColumnClampsInsteadOfWrapping () {
        let span = PointerSelectionMath.span(pivot: Position(col: 0, row: 1),
                                             hit: Position(col: 79, row: 1), cols: cols)
        XCTAssertEqual(span.end, Position(col: 79, row: 1))
    }
}
