import Foundation

public enum TimerOptions {
    public static let focus = [2] + Array(stride(from: 5, through: 60, by: 5)) + [75, 90, 105, 120]
    public static let rest = Array(1...10) + [15, 20, 30, 40, 50, 60]
    public static func label(_ minutes: Int) -> String {
        return "\(minutes) min"
    }
}

public struct EffectSettings: Codable, Equatable {
    public var size: Double
    public var gravity: Double
    public var speed: Double
    public var travel: Double
    public var travelSpeed: Double
    public init(size: Double, gravity: Double, speed: Double, travel: Double, travelSpeed: Double = 1) {
        self.size = size; self.gravity = gravity; self.speed = speed
        self.travel = travel; self.travelSpeed = travelSpeed
    }
    enum CodingKeys: String, CodingKey { case size, gravity, speed, travel, travelSpeed }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        size = try c.decode(Double.self,forKey: .size); gravity = try c.decode(Double.self,forKey: .gravity)
        speed = try c.decode(Double.self,forKey: .speed); travel = try c.decode(Double.self,forKey: .travel)
        travelSpeed = try c.decodeIfPresent(Double.self,forKey: .travelSpeed) ?? 1
    }
    public static let standard = EffectSettings(size: 0.99, gravity: 5.4, speed: 1.4, travel: 0.75, travelSpeed: 5.3)
    public static let gentle = EffectSettings(size: 0.12, gravity: 1.0, speed: 0.6, travel: 0.3)
    public static let strong = EffectSettings(size: 0.55, gravity: 5.5, speed: 1.4, travel: 0.5)
    public static let extreme = EffectSettings(size: 1.4, gravity: 9, speed: 2.6, travel: 1)
    public var preset: String {
        self == .standard ? "Default" : self == .gentle ? "Gentle" : self == .strong ? "Strong" : self == .extreme ? "Extreme" : "Custom"
    }
    public var clamped: EffectSettings {
        func safe(_ x: Double, _ range: ClosedRange<Double>, _ fallback: Double) -> Double {
            x.isFinite ? min(range.upperBound, max(range.lowerBound, x)) : fallback
        }
        return EffectSettings(size: safe(size, SizeScale.range, 0.55), gravity: safe(gravity, 0...10, 2.3),
            speed: safe(speed, 0...10, 1.4), travel: safe(travel, 0...1, 0.75), travelSpeed: safe(travelSpeed,0...10,1))
    }
}

/// Log spacing gives precise control over small sizes; geometry always fits the display.
public enum SizeScale {
    public static let range = 0.02...1.4
    public static func value(at position: Double) -> Double {
        exp(log(range.lowerBound)+min(1,max(0,position)) * log(range.upperBound/range.lowerBound))
    }
    public static func position(for value: Double) -> Double {
        log(min(range.upperBound,max(range.lowerBound,value))/range.lowerBound) / log(range.upperBound/range.lowerBound)
    }
}

public struct BreakVisual {
    public var growth: Double
    public var movementTime: Double
    public init(growth: Double,movementTime: Double) { self.growth = growth; self.movementTime = movementTime }
}

public enum BreakEffect {
    public static func sample(elapsed: Double, duration: Double) -> BreakVisual {
        let duration = duration.isFinite ? max(1,duration) : 300
        let t = elapsed.isFinite ? min(duration,max(0,elapsed)) : 0
        let grow = min(3,duration*0.15), shrink = min(10,duration*0.2)
        func smooth(_ x: Double) -> Double { let v = min(1,max(0,x)); return v*v*(3-2*v) }
        let growth = t < grow ? smooth(t/grow) : t > duration-shrink ? smooth((duration-t)/shrink) : 1
        return BreakVisual(growth: growth,movementTime: max(0,t-grow))
    }
}

public struct PreviewSample {
    public var progress: Double
    public var growth: Double
    public var movementTime: Double
    public var phase: Session.Phase
    public init(progress: Double,growth: Double,movementTime: Double,phase: Session.Phase) {
        self.progress = progress; self.growth = growth; self.movementTime = movementTime; self.phase = phase
    }
}

public enum PreviewCycle {
    public static func effect(at elapsed: Double) -> PreviewSample {
        PreviewSample(progress: 1,growth: 1,movementTime: max(0,elapsed.isFinite ? elapsed : 0),phase: .rest)
    }
    public static func sample(at elapsed: Double) -> PreviewSample {
        let t = min(30,max(0,elapsed.isFinite ? elapsed : 0))
        if t < 10 { return PreviewSample(progress: t/30,growth: 0,movementTime: 0,phase: .focus) }
        if t >= 30 { return PreviewSample(progress: 1,growth: 0,movementTime: 0,phase: .complete) }
        let visual = BreakEffect.sample(elapsed: t-10,duration: 20)
        return PreviewSample(progress: t/30,growth: visual.growth,movementTime: visual.movementTime,phase: .rest)
    }
}

/// An explicit desktop test has its own clock, independent of preview mode or scrubbing.
public enum DesktopTestTimeline {
    public static let duration: Double = 10
    public static func sample(elapsed: Double) -> PreviewSample {
        let t = elapsed.isFinite ? min(duration,max(0,elapsed)) : 0
        return PreviewSample(progress: t/duration,growth: t < duration ? 1 : 0,
            movementTime: t,phase: t < duration ? .rest : .complete)
    }
}
