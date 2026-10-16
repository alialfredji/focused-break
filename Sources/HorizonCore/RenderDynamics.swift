import Foundation

/// Continuous phase integration: changing speed never re-multiplies elapsed time.
public struct RenderDynamics {
    public private(set) var settings: EffectSettings?
    public private(set) var spin: Double = 0
    public private(set) var travelPhase: Double = 0
    private var lastWall: Double?
    private var lastSource: Double?
    private var lastTravel: Double?
    public init() {}
    public mutating func sample(target: EffectSettings, source: Double, travel: Double, wall: Double, reduced: Bool) {
        let target = target.clamped
        let dt = min(0.1,max(0,wall-(lastWall ?? wall)))
        var value = settings ?? target
        let blend = 1-exp(-dt/0.14)
        func ease(_ old: Double,_ new: Double) -> Double { old+(new-old)*blend }
        value.size = ease(value.size,target.size); value.gravity = ease(value.gravity,target.gravity)
        value.speed = ease(value.speed,target.speed); value.travel = ease(value.travel,target.travel)
        value.travelSpeed = ease(value.travelSpeed,target.travelSpeed)
        if source < (lastSource ?? source) || travel < (lastTravel ?? travel) { spin = 0; travelPhase = 0 }
        if !reduced {
            spin += min(0.1,max(0,source-(lastSource ?? source))) * value.speed
            let acceleration = 1-exp(-max(0,travel)*2)
            travelPhase += min(0.1,max(0,travel-(lastTravel ?? travel))) * value.travelSpeed * acceleration
        }
        settings = value; lastWall = wall; lastSource = source; lastTravel = travel
    }
}
