import Foundation
import SwiftUI
import SkyhopCore

/// Draws a `GameState` into a SwiftUI `GraphicsContext`. One world unit equals the canvas height.
/// Repeating patterns use (parallax factor * 60) as a multiple of their period, so nothing
/// jumps when `GameState.distance` wraps around.
enum GameRenderer {
    private struct Star {
        let xFraction: Double
        let y: Double
        let radius: Double
        let phase: Double
    }

    private static let stars: [Star] = {
        var seed: UInt64 = 7
        func next() -> Double { // tiny LCG, the sky looks the same on every launch
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(seed >> 11) / Double(1 << 53)
        }
        return (0..<36).map { _ in
            Star(xFraction: next(), y: next() * 0.38, radius: 0.0018 + next() * 0.0022, phase: next() * 6)
        }
    }()

    private static let sky = Gradient(stops: [
        .init(color: Palette.skyTop, location: 0),
        .init(color: Palette.skyMid, location: 0.55),
        .init(color: Palette.skyBottom, location: 1),
    ])

    private static let pipeGradient = Gradient(stops: [
        .init(color: Palette.pipeLight, location: 0),
        .init(color: Palette.pipeMid, location: 0.35),
        .init(color: Palette.pipeDark, location: 1),
    ])

    static func draw(_ state: GameState, config: GameConfig, in context: inout GraphicsContext, size: CGSize) {
        let unit = size.height
        guard unit > 0 else { return }

        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(sky, startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height))
        )
        drawStars(state, unit: unit, size: size, in: &context)
        drawClouds(state, unit: unit, size: size, in: &context)
        drawHills(state, config: config, unit: unit, size: size, factor: 0.25, period: 1.0, height: 0.10, amplitude: 0.035, color: Palette.hillFar, in: &context)
        drawHills(state, config: config, unit: unit, size: size, factor: 0.5, period: 0.75, height: 0.05, amplitude: 0.03, color: Palette.hillNear, in: &context)
        for pipe in state.pipes {
            drawPipe(pipe, config: config, unit: unit, in: &context)
        }
        drawGround(state, config: config, unit: unit, size: size, in: &context)
        drawBird(state, config: config, unit: unit, in: &context)
    }

    // MARK: - Background

    private static func circle(_ cx: Double, _ cy: Double, _ r: Double) -> Path {
        Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
    }

    private static func drawStars(_ state: GameState, unit: Double, size: CGSize, in context: inout GraphicsContext) {
        for star in stars {
            let twinkle = 0.55 + 0.45 * sin(state.time * 1.7 + star.phase)
            context.fill(
                circle(star.xFraction * size.width, star.y * unit, star.radius * unit),
                with: .color(Palette.star.opacity(twinkle))
            )
        }
    }

    private static func drawClouds(_ state: GameState, unit: Double, size: CGSize, in context: inout GraphicsContext) {
        let period = 1.2
        let offset = (state.distance * 0.2).truncatingRemainder(dividingBy: period)
        let count = Int((size.width / unit / period).rounded(.up)) + 1
        for i in -1...count {
            let base = Double(i) * period - offset
            cloud(x: base + 0.25, y: 0.2, r: 0.05, unit: unit, in: &context)
            cloud(x: base + 0.85, y: 0.33, r: 0.035, unit: unit, in: &context)
        }
    }

    private static func cloud(x: Double, y: Double, r: Double, unit: Double, in context: inout GraphicsContext) {
        let shading = GraphicsContext.Shading.color(Palette.cloud)
        context.fill(circle(x * unit, y * unit, r * unit), with: shading)
        context.fill(circle((x - r * 1.1) * unit, (y + r * 0.25) * unit, r * 0.8 * unit), with: shading)
        context.fill(circle((x + r * 1.1) * unit, (y + r * 0.3) * unit, r * 0.75 * unit), with: shading)
    }

    private static func drawHills(
        _ state: GameState, config: GameConfig, unit: Double, size: CGSize,
        factor: Double, period: Double, height: Double, amplitude: Double, color: Color,
        in context: inout GraphicsContext
    ) {
        let offset = (state.distance * factor).truncatingRemainder(dividingBy: period)
        let base = config.groundTop - height
        let step = 4.0 // points between path samples
        var path = Path()
        path.move(to: CGPoint(x: 0, y: config.groundTop * unit))
        var px = 0.0
        while px <= size.width + step {
            let worldX = px / unit + offset
            let wave = 0.5 + 0.5 * sin(worldX / period * 2 * .pi)
            path.addLine(to: CGPoint(x: px, y: (base - amplitude * wave) * unit))
            px += step
        }
        path.addLine(to: CGPoint(x: size.width + step, y: config.groundTop * unit))
        path.closeSubpath()
        context.fill(path, with: .color(color))
    }

    // MARK: - Pipes & ground

    private static func drawPipe(_ pipe: PipePair, config: GameConfig, unit: Double, in context: inout GraphicsContext) {
        let left = pipe.x * unit
        let width = config.pipeWidth * unit
        let gapTop = (pipe.gapCenterY - config.pipeGap / 2) * unit
        let gapBottom = (pipe.gapCenterY + config.pipeGap / 2) * unit
        let groundTop = config.groundTop * unit

        let body = GraphicsContext.Shading.linearGradient(
            pipeGradient, startPoint: CGPoint(x: left, y: 0), endPoint: CGPoint(x: left + width, y: 0)
        )
        context.fill(Path(CGRect(x: left, y: 0, width: width, height: gapTop)), with: body)
        context.fill(Path(CGRect(x: left, y: gapBottom, width: width, height: groundTop - gapBottom)), with: body)

        let capHeight = 0.035 * unit
        let overhang = width * 0.08
        let cap = GraphicsContext.Shading.linearGradient(
            pipeGradient,
            startPoint: CGPoint(x: left - overhang, y: 0),
            endPoint: CGPoint(x: left + width + overhang, y: 0)
        )
        let corner = CGSize(width: capHeight * 0.25, height: capHeight * 0.25)
        let capWidth = width + overhang * 2
        context.fill(
            Path(roundedRect: CGRect(x: left - overhang, y: gapTop - capHeight, width: capWidth, height: capHeight), cornerSize: corner),
            with: cap
        )
        context.fill(
            Path(roundedRect: CGRect(x: left - overhang, y: gapBottom, width: capWidth, height: capHeight), cornerSize: corner),
            with: cap
        )
    }

    private static func drawGround(_ state: GameState, config: GameConfig, unit: Double, size: CGSize, in context: inout GraphicsContext) {
        let top = config.groundTop * unit
        context.fill(Path(CGRect(x: 0, y: top, width: size.width, height: size.height - top)), with: .color(Palette.ground))

        let band = 0.022 * unit
        let bandRect = CGRect(x: 0, y: top, width: size.width, height: band)
        context.fill(Path(bandRect), with: .color(Palette.grass))

        var stripes = context
        stripes.clip(to: Path(bandRect))
        let stripe = 0.06
        let offset = state.distance.truncatingRemainder(dividingBy: stripe)
        var x = -offset - stripe
        while x * unit < size.width {
            var path = Path()
            path.move(to: CGPoint(x: x * unit, y: top + band))
            path.addLine(to: CGPoint(x: (x + 0.03) * unit, y: top + band))
            path.addLine(to: CGPoint(x: (x + 0.045) * unit, y: top))
            path.addLine(to: CGPoint(x: (x + 0.015) * unit, y: top))
            path.closeSubpath()
            stripes.fill(path, with: .color(Palette.grassLight))
            x += stripe
        }

        context.fill(Path(CGRect(x: 0, y: top + band, width: size.width, height: 0.008 * unit)), with: .color(Palette.groundShade))
    }

    // MARK: - Bird

    private static func drawBird(_ state: GameState, config: GameConfig, unit: Double, in context: inout GraphicsContext) {
        let r = config.birdRadius * unit
        let flap = state.phase == .gameOver ? 0 : sin(state.time * 22)

        // Draw around the origin of a translated and rotated copy of the context.
        var bird = context
        bird.translateBy(x: state.birdX(config) * unit, y: state.birdY * unit)
        bird.rotate(by: .degrees(state.birdRotation))

        bird.fill(circle(0, 0, r), with: .color(Palette.birdBody))
        bird.fill(Path(ellipseIn: CGRect(x: -r * 0.55, y: r * 0.05, width: r * 1.1, height: r * 0.75)), with: .color(Palette.birdBelly))

        let wingHeight = r * (0.6 + 0.25 * flap)
        bird.fill(
            Path(ellipseIn: CGRect(x: -r * 1.0, y: -wingHeight / 2 + r * 0.12 * flap, width: r * 1.05, height: wingHeight)),
            with: .color(Palette.birdWing)
        )

        bird.fill(circle(r * 0.38, -r * 0.32, r * 0.36), with: .color(.white))
        bird.fill(circle(r * 0.5, -r * 0.3, r * 0.16), with: .color(Palette.pupil))

        var beak = Path()
        beak.move(to: CGPoint(x: r * 0.7, y: -r * 0.05))
        beak.addLine(to: CGPoint(x: r * 1.4, y: r * 0.17))
        beak.addLine(to: CGPoint(x: r * 0.7, y: r * 0.42))
        beak.closeSubpath()
        bird.fill(beak, with: .color(Palette.beak))
    }
}
