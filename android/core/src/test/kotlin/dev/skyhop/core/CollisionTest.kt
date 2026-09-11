package dev.skyhop.core

import org.junit.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class CollisionTest {
    @Test
    fun circleInsideRectCollides() {
        assertTrue(Collision.circleIntersectsRect(0.5f, 0.5f, 0.1f, 0f, 0f, 1f, 1f))
    }

    @Test
    fun circleTouchingEdgeFromOutsideCollides() {
        assertTrue(Collision.circleIntersectsRect(1.05f, 0.5f, 0.1f, 0f, 0f, 1f, 1f))
    }

    @Test
    fun circleFarAwayDoesNotCollide() {
        assertFalse(Collision.circleIntersectsRect(2f, 2f, 0.1f, 0f, 0f, 1f, 1f))
    }

    @Test
    fun cornerUsesRealDistanceNotBoundingBox() {
        // Inside the bounding box of the circle but outside the circle itself.
        assertFalse(Collision.circleIntersectsRect(1.08f, 1.08f, 0.1f, 0f, 0f, 1f, 1f))
        assertTrue(Collision.circleIntersectsRect(1.05f, 1.05f, 0.1f, 0f, 0f, 1f, 1f))
    }
}
