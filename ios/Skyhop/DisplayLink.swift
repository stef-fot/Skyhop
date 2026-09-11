import QuartzCore

/// Calls `onFrame` once per screen refresh with the elapsed time in seconds.
/// Runs at up to 120 Hz on ProMotion displays (see CADisableMinimumFrameDurationOnPhone in Info.plist).
@MainActor
final class DisplayLink {
    private var link: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?
    private let onFrame: @MainActor (Double) -> Void

    init(onFrame: @escaping @MainActor (Double) -> Void) {
        self.onFrame = onFrame
    }

    func start() {
        guard link == nil else { return }
        let link = CADisplayLink(target: Proxy(owner: self), selector: #selector(Proxy.handle(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func stop() {
        link?.invalidate()
        link = nil
        lastTimestamp = nil
    }

    fileprivate func tick(_ link: CADisplayLink) {
        defer { lastTimestamp = link.timestamp }
        guard let last = lastTimestamp else { return } // first frame only records the time
        onFrame(link.timestamp - last)
    }
}

/// CADisplayLink keeps a strong reference to its target. The proxy holds the owner weakly,
/// so there is no retain cycle, and it stops the link by itself if the owner goes away.
@MainActor
private final class Proxy: NSObject {
    weak var owner: DisplayLink?

    init(owner: DisplayLink) {
        self.owner = owner
    }

    @objc func handle(_ link: CADisplayLink) {
        guard let owner else {
            link.invalidate()
            return
        }
        owner.tick(link)
    }
}
