import Foundation

/// Coordinates are measured in display-height units, shared by preview and overlay.
public struct LensGeometry {
    public let radius: Double
    public let centerX: Double
    public let centerY: Double
    public let extent: Double

    public init(aspect: Double, size: Double, growth: Double, travel: Double, phase: Double) {
        let aspect = aspect.isFinite ? max(0.1,aspect) : 1
        let size = size.isFinite ? min(1.4,max(0.02,size)) : 0.55
        let g = growth.isFinite ? min(1,max(0,growth)) : 0
        radius = min(aspect,1)*0.18*size*g
        // Includes the rim, soft glow and custom asset's largest half-dimension.
        extent = radius*1.65+min(aspect,1)*0.025
        let amount = travel.isFinite ? min(1,max(0,travel)) : 0
        let t = phase.isFinite ? phase : 0
        centerX = 0.5+sin(t*0.14)*max(0,0.5-extent/aspect)*amount
        centerY = 0.5+sin(t*0.11)*max(0,0.5-extent)*amount
    }
}

public enum AnimationTimeline {
    public static func frame(at time: Double, durations: [Double], reducedMotion: Bool = false) -> Int {
        guard !reducedMotion, durations.count > 1, time.isFinite else { return 0 }
        let safe = durations.map { $0.isFinite && $0 >= 0.02 ? $0 : 0.1 }
        let total = safe.reduce(0,+)
        var remaining = max(0,time).truncatingRemainder(dividingBy: total)
        for (index,duration) in safe.enumerated() {
            if remaining < duration { return index }
            remaining -= duration
        }
        return 0
    }
}
