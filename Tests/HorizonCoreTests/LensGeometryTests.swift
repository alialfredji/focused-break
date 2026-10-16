import XCTest
@testable import HorizonCore

final class LensGeometryTests: XCTestCase {
    func testVisibleEffectRemainsInsidePortraitAndWideDisplaysAtAllTravelPhases() {
        for aspect in [0.5,0.75,1,1.6,2.4,4] {
            for size in [0.02,0.55,1.4,4] {
                for phase in stride(from: 0.0,through: 1000,by: 1.7) {
                    let g = LensGeometry(aspect: aspect,size: size,growth: 1,travel: 1,phase: phase)
                    XCTAssertGreaterThanOrEqual(g.centerX*aspect-g.extent,-0.000001)
                    XCTAssertLessThanOrEqual(g.centerX*aspect+g.extent,aspect+0.000001)
                    XCTAssertGreaterThanOrEqual(g.centerY-g.extent,-0.000001)
                    XCTAssertLessThanOrEqual(g.centerY+g.extent,1.000001)
                }
            }
        }
    }
    func testGrowthAndStillCenter() {
        let hidden = LensGeometry(aspect: 1.6,size: 1.4,growth: 0,travel: 1,phase: 20)
        XCTAssertEqual(hidden.radius,0)
        let still = LensGeometry(aspect: 1.6,size: 1.4,growth: 1,travel: 0,phase: 20)
        XCTAssertEqual(still.centerX,0.5); XCTAssertEqual(still.centerY,0.5)
    }
    func testAnimationUsesOriginalUnequalFrameDurationsAndLoops() {
        let durations = [0.1,0.3,0.2]
        XCTAssertEqual(AnimationTimeline.frame(at: 0.05,durations: durations),0)
        XCTAssertEqual(AnimationTimeline.frame(at: 0.15,durations: durations),1)
        XCTAssertEqual(AnimationTimeline.frame(at: 0.45,durations: durations),2)
        XCTAssertEqual(AnimationTimeline.frame(at: 0.65,durations: durations),0)
        XCTAssertEqual(AnimationTimeline.frame(at: 0.45,durations: durations,reducedMotion: true),0)
        XCTAssertEqual(AnimationTimeline.frame(at: .nan,durations: durations),0)
    }
}
