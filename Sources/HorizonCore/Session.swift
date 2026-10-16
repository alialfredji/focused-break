import Foundation

/// A deterministic, elapsed-time clock. The UI supplies monotonic time, never tick counts.
public struct Session {
    public enum Phase: String { case ready, focus, rest, complete }
    public private(set) var phase: Phase = .ready
    public private(set) var isPaused = false
    public private(set) var isDemo = false
    public private(set) var elapsed: TimeInterval = 0
    public private(set) var focusDuration: TimeInterval = 25 * 60
    public private(set) var restDuration: TimeInterval = 5 * 60
    public private(set) var minimumBreakDuration: TimeInterval = 5
    private var lastTime: TimeInterval?

    public init() {}
    public var isActive: Bool { phase == .focus || phase == .rest }
    public var showsDesktopEffect: Bool { phase == .rest && !isPaused }
    public func breakLockRemaining(now: TimeInterval) -> Int {
        guard phase == .rest else { return 0 }
        return Int(ceil(max(0,minimumBreakDuration-renderElapsed(now: now))))
    }
    /// Render between timer ticks without mutating timer state or counting paused time.
    public func renderElapsed(now: TimeInterval) -> TimeInterval {
        guard isActive, !isPaused, let lastTime else { return elapsed }
        return min(duration,elapsed + max(0,now-lastTime))
    }
    public var duration: TimeInterval { phase == .rest ? restDuration : focusDuration }
    public var remaining: TimeInterval { max(0, duration - elapsed) }
    public var progress: Double { min(1, max(0, elapsed / max(1, duration))) }

    public mutating func start(focus: TimeInterval, rest: TimeInterval, now: TimeInterval, demo: Bool = false, minimumBreak: TimeInterval = 5) {
        focusDuration = focus.isFinite ? max(1, focus) : 1500
        restDuration = rest.isFinite ? max(1, rest) : 300
        minimumBreakDuration = minimumBreak.isFinite ? min(300,max(5,minimumBreak)) : 5
        restDuration = max(restDuration,minimumBreakDuration)
        isDemo = demo; phase = .focus; isPaused = false; elapsed = 0; lastTime = now
    }

    public mutating func tick(now: TimeInterval) {
        guard isActive, !isPaused else { return }
        let delta = max(0, now - (lastTime ?? now))
        lastTime = now
        elapsed += delta
        if elapsed >= duration {
            // A delayed tick starts a full break; time spent working is never counted as rest.
            if phase == .focus { phase = .rest; elapsed = 0 }
            else { phase = .complete; elapsed = restDuration; lastTime = nil }
        }
    }

    public mutating func pause(now: TimeInterval) {
        guard isActive, !isPaused else { return }
        tick(now: now)
        if isActive { isPaused = true; lastTime = nil }
    }
    public mutating func resume(now: TimeInterval) {
        guard isActive, isPaused else { return }
        isPaused = false; lastTime = now
    }
    public mutating func takeBreak(now: TimeInterval) {
        guard phase == .focus else { return }
        phase = .rest; elapsed = 0; isPaused = false; lastTime = now
    }
    public mutating func stop() { self = Session() }
}
