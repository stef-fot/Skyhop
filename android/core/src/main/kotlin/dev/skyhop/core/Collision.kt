package dev.skyhop.core

object Collision {
    /** Circle vs axis aligned rectangle, using the closest point of the rectangle to the circle center. */
    fun circleIntersectsRect(
        cx: Float, cy: Float, radius: Float,
        left: Float, top: Float, right: Float, bottom: Float,
    ): Boolean {
        val nearestX = cx.coerceIn(left, right)
        val nearestY = cy.coerceIn(top, bottom)
        val dx = cx - nearestX
        val dy = cy - nearestY
        return dx * dx + dy * dy < radius * radius
    }
}
