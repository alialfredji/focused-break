import XCTest
@testable import HorizonCore

final class RenderDynamicsTests: XCTestCase {
    func testSessionRenderClockAdvancesEveryFrameBetweenTimerTicks() {
        var session = Session()
        session.start(focus: 10,rest: 60,now: 0)
        session.takeBreak(now: 0)
        for frame in 1...5 {
            XCTAssertEqual(session.renderElapsed(now: Double(frame)/60),Double(frame)/60,accuracy: 0.000001)
        }
        XCTAssertEqual(session.elapsed,0)
        session.pause(now: 0.1)
        XCTAssertEqual(session.renderElapsed(now: 10),0.1,accuracy: 0.000001)
    }
    func testSpeedChangeDoesNotTeleportPhaseAndSettingsEase() {
        var dynamics = RenderDynamics()
        let initial = EffectSettings(size: 0.1,gravity: 0,speed: 1,travel: 1)
        dynamics.sample(target: initial,source: 100,travel: 100,wall: 100,reduced: false)
        var faster = initial; faster.speed = 10; faster.gravity = 10; faster.size = 1
        dynamics.sample(target: faster,source: 100+1.0/60,travel: 100+1.0/60,wall: 100+1.0/60,reduced: false)
        XCTAssertLessThan(dynamics.spin,0.2)
        XCTAssertGreaterThan(dynamics.settings!.gravity,0)
        XCTAssertLessThan(dynamics.settings!.gravity,10)
        XCTAssertLessThan(dynamics.settings!.size,1)
    }
    func testTravelSpeedIsIndependentAndPauseFreezesBothClocks() {
        var dynamics = RenderDynamics()
        let settings = EffectSettings(size: 0.3,gravity: 10,speed: 0,travel: 1,travelSpeed: 10)
        dynamics.sample(target: settings,source: 1,travel: 1,wall: 1,reduced: false)
        dynamics.sample(target: settings,source: 1.05,travel: 1.05,wall: 1.05,reduced: false)
        XCTAssertEqual(dynamics.spin,0)
        XCTAssertGreaterThan(dynamics.travelPhase,0)
        let before = dynamics.travelPhase
        dynamics.sample(target: settings,source: 1.05,travel: 1.05,wall: 2,reduced: false)
        XCTAssertEqual(dynamics.travelPhase,before)
        dynamics.sample(target: settings,source: 1.1,travel: 1.1,wall: 2.05,reduced: true)
        XCTAssertEqual(dynamics.travelPhase,before)
    }
}
