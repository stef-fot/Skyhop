import XCTest
@testable import SkyhopCore

final class CollisionTests: XCTestCase {
    func testCircleInsideRectCollides() {
        XCTAssertTrue(Collision.circleIntersectsRect(cx: 0.5, cy: 0.5, radius: 0.1, left: 0, top: 0, right: 1, bottom: 1))
    }

    func testCircleTouchingEdgeFromOutsideCollides() {
        XCTAssertTrue(Collision.circleIntersectsRect(cx: 1.05, cy: 0.5, radius: 0.1, left: 0, top: 0, right: 1, bottom: 1))
    }

    func testCircleFarAwayDoesNotCollide() {
        XCTAssertFalse(Collision.circleIntersectsRect(cx: 2, cy: 2, radius: 0.1, left: 0, top: 0, right: 1, bottom: 1))
    }

    func testCornerUsesRealDistanceNotBoundingBox() {
        XCTAssertFalse(Collision.circleIntersectsRect(cx: 1.08, cy: 1.08, radius: 0.1, left: 0, top: 0, right: 1, bottom: 1))
        XCTAssertTrue(Collision.circleIntersectsRect(cx: 1.05, cy: 1.05, radius: 0.1, left: 0, top: 0, right: 1, bottom: 1))
    }
}
