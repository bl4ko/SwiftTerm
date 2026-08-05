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
        // Start anchor is at (50, 80); a fat finger a cell right and below
        // still grabs it, and the offset points back at the true start cell.
        let hit = grab(CGPoint(x: 62, y: 95))
        XCTAssertEqual(hit, SelectionHandleGrab(handle: .start, colOffset: -1, rowOffset: -1))
    }

    func testGrabsEndHandleWithOffset () {
        // End anchor is at (120, 60); touching just above-right of it.
        let hit = grab(CGPoint(x: 128, y: 51))
        XCTAssertEqual(hit, SelectionHandleGrab(handle: .end, colOffset: 0, rowOffset: 1))
    }

    func testGrabInsideStartCellHasZeroOffset () {
        let hit = grab(CGPoint(x: 55, y: 75))
        XCTAssertEqual(hit, SelectionHandleGrab(handle: .start, colOffset: 0, rowOffset: 0))
    }

    func testGrabOnAnchorCompensatesBackToStartCell () {
        // The start anchor (50, 80) lies on the row boundary below the start
        // cell; the offset must point the drag back at the real start row.
        let hit = grab(CGPoint(x: 50, y: 80))
        XCTAssertEqual(hit, SelectionHandleGrab(handle: .start, colOffset: 0, rowOffset: -1))
    }

    func testFarTouchGrabsNothing () {
        XCTAssertNil(grab(CGPoint(x: 200, y: 300)))
        XCTAssertNil(grab(CGPoint(x: 85, y: 70), slop: 10))
    }

    func testNearestHandleWins () {
        // Midway-ish point closer to the end anchor.
        let hit = grab(CGPoint(x: 110, y: 62), slop: 60)
        XCTAssertEqual(hit?.handle, .end)
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
