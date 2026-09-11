import Foundation

public enum Collision {
    /// Circle vs axis aligned rectangle, using the closest point of the rectangle to the circle center.
    public static func circleIntersectsRect(
        cx: Double, cy: Double, radius: Double,
        left: Double, top: Double, right: Double, bottom: Double
    ) -> Bool {
        let nearestX = min(max(cx, left), right)
        let nearestY = min(max(cy, top), bottom)
        let dx = cx - nearestX
        let dy = cy - nearestY
        return dx * dx + dy * dy < radius * radius
    }
}
