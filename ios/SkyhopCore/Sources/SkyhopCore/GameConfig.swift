import Foundation

/// Tunable game constants.
///
/// Everything is in world units: the world is always 1.0 tall and its width depends on the
/// screen aspect ratio. Physics never sees points or pixels, so the game feels the same on
/// every device. The y axis points down, like the SwiftUI canvas.
public struct GameConfig: Equatable, Sendable {
    public var groundHeight = 0.12
    public var birdRadius = 0.026
    /// Horizontal bird position as a fraction of the world width.
    public var birdXRatio = 0.3
    public var startY = 0.42
    /// Units per second squared.
    public var gravity = 2.6
    /// Instant vertical velocity applied on every flap (negative = up).
    public var flapVelocity = -0.78
    public var maxFallSpeed = 1.3
    public var pipeWidth = 0.13
    public var pipeGap = 0.25
    /// Distance between the left edges of two consecutive pipes.
    public var pipeSpacing = 0.44
    /// How far beyond the right edge the first pipe appears.
    public var firstPipeOffset = 0.2
    public var scrollSpeed = 0.28
    /// Minimum distance between a gap and the top of the screen or the ground.
    public var gapMargin = 0.08
    /// Maximum vertical jump between two consecutive gaps, keeps every level beatable.
    public var maxGapShift = 0.22
    /// The collision circle is slightly smaller than the drawn bird, which feels fairer.
    public var hitboxScale = 0.85
    /// Frame time is clamped so a hiccup (or resuming the app) never teleports the bird.
    public var maxFrameTime = 1.0 / 30.0
    /// Seconds after a crash before a tap restarts.
    public var restartDelay = 0.6

    public init() {}

    public var groundTop: Double { 1 - groundHeight }
    public var minGapCenter: Double { gapMargin + pipeGap / 2 }
    public var maxGapCenter: Double { groundTop - gapMargin - pipeGap / 2 }
}
