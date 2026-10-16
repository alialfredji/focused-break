import XCTest
import AppKit
import ImageIO
import UniformTypeIdentifiers
@testable import HorizonMedia

final class ReminderAssetTests: XCTestCase {
    func testBundledUpscalePreservesAnimationAndTransparency() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let original = try ReminderAsset.read(url: root.appendingPathComponent("assets/HaveABreak-original.gif")).asset
        let upgraded = try ReminderAsset.read(url: root.appendingPathComponent("Sources/EventHorizon/HaveABreak.gif")).asset
        XCTAssertEqual(upgraded.frames.count,original.frames.count)
        XCTAssertEqual(upgraded.durations,original.durations)
        XCTAssertEqual(upgraded.frames[0].width,1024)
        XCTAssertEqual(upgraded.frames[0].height,742)
        XCTAssertEqual(upgraded.aspect,original.aspect,accuracy: 0.002)
        for image in upgraded.frames {
            let rep = NSBitmapImageRep(cgImage: image)
            XCTAssertLessThan(rep.colorAt(x: 100,y: 100)!.alphaComponent,0.01)
        }
        XCTAssertNotEqual(NSBitmapImageRep(cgImage: upgraded.frames[0]).representation(using: .png,properties: [:]),
                          NSBitmapImageRep(cgImage: upgraded.frames[5]).representation(using: .png,properties: [:]))
    }
    private func frame(_ red: CGFloat,_ green: CGFloat) -> CGImage {
        let c = CGContext(data: nil,width: 32,height: 24,bitsPerComponent: 8,bytesPerRow: 128,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        c.setFillColor(CGColor(red: red,green: green,blue: 0,alpha: 1))
        c.fill(CGRect(x: 8,y: 6,width: 16,height: 12))
        return c.makeImage()!
    }
    private func encode(_ type: UTType,_ frames: [CGImage]) -> Data {
        let data = NSMutableData()
        let d = CGImageDestinationCreateWithData(data,type.identifier as CFString,frames.count,nil)!
        for (index,image) in frames.enumerated() {
            let props: [CFString: Any] = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: index == 0 ? 0.1 : 0.3]]
            CGImageDestinationAddImage(d,image,props as CFDictionary)
        }
        XCTAssertTrue(CGImageDestinationFinalize(d)); return data as Data
    }
    func testPNGPreservesAlphaAndAspect() throws {
        let asset = try ReminderAsset.load(data: encode(.png,[frame(1,0)]),name: "transparent.png")
        XCTAssertEqual(asset.aspect,32.0/24,accuracy: 0.001)
        XCTAssertEqual(asset.frames.count,1)
        let rep = NSBitmapImageRep(cgImage: asset.frames[0])
        XCTAssertEqual(rep.colorAt(x: 0,y: 0)!.alphaComponent,0,accuracy: 0.01)
        XCTAssertEqual(rep.colorAt(x: 16,y: 12)!.redComponent,1,accuracy: 0.01)
    }
    func testGIFRetainsFramesTimingAndTransparency() throws {
        let asset = try ReminderAsset.load(data: encode(.gif,[frame(1,0),frame(0,1)]),name: "animated.gif")
        XCTAssertEqual(asset.frames.count,2)
        XCTAssertEqual(asset.durations[1],0.3,accuracy: 0.001)
        XCTAssertEqual(asset.frameIndex(time: 0.2,reducedMotion: false),1)
        XCTAssertEqual(asset.frameIndex(time: 0.2,reducedMotion: true),0)
        let first = NSBitmapImageRep(cgImage: asset.frames[0]), second = NSBitmapImageRep(cgImage: asset.frames[1])
        XCTAssertGreaterThan(first.colorAt(x: 16,y: 12)!.redComponent,0.9)
        XCTAssertGreaterThan(second.colorAt(x: 16,y: 12)!.greenComponent,0.9)
        XCTAssertLessThan(second.colorAt(x: 0,y: 0)!.alphaComponent,0.01)
    }
    func testInvalidAndOversizedInputAreRejected() {
        XCTAssertThrowsError(try ReminderAsset.load(data: Data("not an image".utf8),name: "bad.png"))
        XCTAssertThrowsError(try ReminderAsset.load(data: Data(count: 26*1024*1024),name: "large.gif"))
    }
}
