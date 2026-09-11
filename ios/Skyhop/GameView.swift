import SwiftUI
import SkyhopCore

struct GameView: View {
    @State private var viewModel = GameViewModel()
    @State private var displayLink: DisplayLink?
    @State private var fingerDown = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                GameCanvas(viewModel: viewModel)
                    .onAppear { viewModel.resize(to: proxy.size) }
                    .onChange(of: proxy.size) { _, newSize in viewModel.resize(to: newSize) }
            }
            .ignoresSafeArea()

            HudView(hud: viewModel.hud)
        }
        .background(Palette.skyTop)
        .contentShape(Rectangle())
        // React on finger down (not on release): games need the lowest possible latency.
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !fingerDown else { return }
                    fingerDown = true
                    viewModel.tap()
                }
                .onEnded { _ in fingerDown = false }
        )
        .onAppear(perform: startLoop)
        .onDisappear { displayLink?.stop() }
        // Pause automatically when the app goes to the background or a call comes in.
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { viewModel.pause() }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: viewModel.hud.score) { old, new in new > old }
        .sensoryFeedback(.impact(weight: .heavy), trigger: viewModel.hitCount)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }

    private func startLoop() {
        if displayLink == nil {
            let model = viewModel
            displayLink = DisplayLink { deltaTime in model.tick(deltaTime) }
        }
        displayLink?.start()
    }
}

/// Separate view so only the canvas is re-evaluated every frame, not the overlay.
private struct GameCanvas: View {
    let viewModel: GameViewModel

    var body: some View {
        let state = viewModel.state
        let config = viewModel.config
        Canvas { context, size in
            GameRenderer.draw(state, config: config, in: &context, size: size)
        }
        .accessibilityLabel(Text(verbatim: "Skyhop"))
        .accessibilityValue(Text(verbatim: "\(state.score)"))
    }
}

// MARK: - Overlay

private struct HudView: View {
    let hud: HudState

    var body: some View {
        ZStack {
            switch hud.phase {
            case .ready:
                ReadyOverlay(best: hud.best)
            case .playing:
                ScoreLabel(score: hud.score)
            case .paused:
                ScoreLabel(score: hud.score)
                VStack(spacing: 8) {
                    Text("Paused").gameTitle(size: 40)
                    PulsingHint(text: "Tap to resume")
                }
            case .gameOver:
                EmptyView()
            }

            if hud.phase == .gameOver {
                GameOverCard(hud: hud)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(duration: 0.35), value: hud.phase == .gameOver)
        .allowsHitTesting(false)
    }
}

private struct ScoreLabel: View {
    let score: Int

    var body: some View {
        VStack {
            Text(verbatim: "\(score)")
                .gameTitle(size: 64)
                .padding(.top, 32)
            Spacer()
        }
    }
}

private struct ReadyOverlay: View {
    let best: Int

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 4) {
                Text(verbatim: "Skyhop").gameTitle(size: 56)
                if best > 0 {
                    Text("Best \(best)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .position(x: geo.size.width / 2, y: geo.size.height * 0.2)

            PulsingHint(text: "Tap to fly")
                .position(x: geo.size.width / 2, y: geo.size.height * 0.64)
        }
    }
}

private struct PulsingHint: View {
    let text: LocalizedStringKey
    @State private var dimmed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(text)
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.35), radius: 0, x: 0, y: 3)
            .opacity(dimmed ? 0.45 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                    dimmed = true
                }
            }
    }
}

private struct GameOverCard: View {
    let hud: HudState

    var body: some View {
        VStack(spacing: 0) {
            Text("Game over")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(Palette.cardInk)

            HStack(spacing: 40) {
                Stat(label: "Score", value: hud.score)
                Stat(label: "Best", value: hud.best)
            }
            .padding(.top, 20)

            if hud.isNewBest {
                Text("New best!")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Palette.badge))
                    .padding(.top, 16)
            }

            Text("Tap to play again")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.cardMuted)
                .opacity(hud.canRestart ? 1 : 0)
                .animation(.easeIn(duration: 0.2), value: hud.canRestart)
                .padding(.top, 22)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 28)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Palette.card)
                .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
        )
        .frame(maxWidth: 320)
    }
}

private struct Stat: View {
    let label: LocalizedStringKey
    let value: Int

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.cardMuted)
            Text(verbatim: "\(value)")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Palette.cardInk)
                .frame(minWidth: 80)
        }
    }
}

private extension View {
    func gameTitle(size: CGFloat) -> some View {
        font(.system(size: size, weight: .black, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.35), radius: 0, x: 0, y: 5)
    }
}

#Preview {
    GameView()
}
