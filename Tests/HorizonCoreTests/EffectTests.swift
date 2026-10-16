import XCTest
@testable import HorizonCore

final class EffectTests: XCTestCase {
    func testScreenshotDefaultsRemainStableAndRecognized() throws {
        let defaults = EffectSettings.standard
        XCTAssertEqual(defaults.size,0.99)
        XCTAssertEqual(defaults.gravity,5.4)
        XCTAssertEqual(defaults.travel,0.75)
        XCTAssertEqual(defaults.travelSpeed,5.3)
        XCTAssertEqual(defaults.preset,"Default")
        XCTAssertEqual(defaults.clamped,defaults)
        XCTAssertEqual(try JSONDecoder().decode(EffectSettings.self,from: JSONEncoder().encode(defaults)),defaults)
    }
    func testDesktopTestIsVisibleImmediatelyEvenWhenSessionPreviewIsClearOrFinished() {
        for previewTime in [0.0,5,30,100] {
            XCTAssertEqual(PreviewCycle.sample(at: previewTime).growth,0)
            XCTAssertEqual(DesktopTestTimeline.sample(elapsed: 0).growth,1)
            XCTAssertEqual(DesktopTestTimeline.sample(elapsed: 8).growth,1)
        }
        XCTAssertEqual(DesktopTestTimeline.sample(elapsed: 9.99).growth,1)
        XCTAssertEqual(DesktopTestTimeline.sample(elapsed: 10).growth,0)
        XCTAssertEqual(DesktopTestTimeline.sample(elapsed: 60).phase,.complete)
        XCTAssertEqual(DesktopTestTimeline.sample(elapsed: .nan).movementTime,0)
    }
    func testSizeRangeHasFineSmallControlAndBoundedEndpoint() {
        XCTAssertEqual(SizeScale.value(at: 0),0.02,accuracy: 0.000001)
        XCTAssertEqual(SizeScale.value(at: 1),1.4,accuracy: 0.000001)
        XCTAssertLessThan(SizeScale.value(at: 0.5),0.3)
        for size in [0.02,0.05,0.12,0.55,1.4] {
            XCTAssertEqual(SizeScale.value(at: SizeScale.position(for: size)),size,accuracy: 0.000001)
        }
        XCTAssertEqual(EffectSettings(size: 4,gravity: 1,speed: 1,travel: 1).clamped.size,1.4)
    }
    func testEffectPreviewNeverWaitsForFocusOrExpires() {
        for time in [0.0,5,10,30,500,3600] {
            XCTAssertEqual(PreviewCycle.effect(at: time).growth,1)
            XCTAssertEqual(PreviewCycle.effect(at: time).movementTime,time)
        }
        XCTAssertEqual(PreviewCycle.sample(at: 5).growth,0)
        XCTAssertEqual(PreviewCycle.sample(at: 500).growth,0)
    }
    func testLegacySettingsAndZeroMotionRemainUsable() throws {
        let legacy = Data(#"{"size":0.6,"gravity":4,"speed":1.4,"travel":0.75,"takeover":true}"#.utf8)
        let settings = try JSONDecoder().decode(EffectSettings.self,from: legacy)
        XCTAssertEqual(settings.size,0.6)
        let still = EffectSettings(size: 0.02,gravity: 0,speed: 0,travel: 0).clamped
        XCTAssertEqual(still.size,0.02)
        XCTAssertEqual(still.speed,0)
        XCTAssertEqual(still.gravity,0)
    }
    func testRequestedTimerRanges() {
        XCTAssertEqual(TimerOptions.focus, [2,5,10,15,20,25,30,35,40,45,50,55,60,75,90,105,120])
        XCTAssertEqual(TimerOptions.rest, [1,2,3,4,5,6,7,8,9,10,15,20,30,40,50,60])
        XCTAssertEqual(TimerOptions.label(2), "2 min")
        XCTAssertEqual(TimerOptions.label(60), "60 min")
        XCTAssertEqual(TimerOptions.label(120), "120 min")
        XCTAssertEqual(TimerOptions.label(105), "105 min")
    }
    func testPreviewKeepsFocusClearAndStopsAfterBreak() {
        XCTAssertEqual(PreviewCycle.sample(at: 9).growth,0)
        XCTAssertEqual(PreviewCycle.sample(at: 9).phase,.focus)
        XCTAssertEqual(PreviewCycle.sample(at: 10).growth,0)
        XCTAssertEqual(PreviewCycle.sample(at: 10).phase,.rest)
        XCTAssertEqual(PreviewCycle.sample(at: 18).growth,1)
        XCTAssertEqual(PreviewCycle.sample(at: 25).growth,1)
        XCTAssertLessThan(PreviewCycle.sample(at: 28).growth,1)
        XCTAssertEqual(PreviewCycle.sample(at: 30).growth,0)
        XCTAssertEqual(PreviewCycle.sample(at: 100).phase,.complete)
        XCTAssertEqual(PreviewCycle.sample(at: 100).progress,1)
        XCTAssertEqual(PreviewCycle.sample(at: .nan).progress,0)
    }
    func testBreakGrowsOnceThenMovesAtConstantSizeAndShrinksOnlyAtEnd() {
        for duration in [20.0,60,120,3600] {
            XCTAssertEqual(BreakEffect.sample(elapsed: 0,duration: duration).growth,0)
            XCTAssertEqual(BreakEffect.sample(elapsed: 1,duration: duration).movementTime,0)
            for t in stride(from: 3.0,through: duration*0.8,by: 1) {
                let visual = BreakEffect.sample(elapsed: t,duration: duration)
                XCTAssertEqual(visual.growth,1)
                XCTAssertEqual(visual.movementTime,t-3,accuracy: 0.0001)
            }
            XCTAssertLessThan(BreakEffect.sample(elapsed: duration-1,duration: duration).growth,1)
            XCTAssertEqual(BreakEffect.sample(elapsed: duration,duration: duration).growth,0)
        }
    }
    func testPersistedSettingsStayWithinRenderBounds() throws {
        let corrupt = EffectSettings(size: -10, gravity: 900, speed: .infinity, travel: .nan).clamped
        XCTAssertEqual(corrupt.size, 0.02)
        XCTAssertEqual(corrupt.gravity, 10)
        XCTAssertEqual(corrupt.speed, 1.4)
        XCTAssertEqual(corrupt.travel, 0.75)
        let data = try JSONEncoder().encode(EffectSettings.extreme)
        XCTAssertEqual(try JSONDecoder().decode(EffectSettings.self, from: data), .extreme)
    }
}
