import AppKit
import ImageIO
import UniformTypeIdentifiers

let directory = URL(fileURLWithPath: CommandLine.arguments[1],isDirectory: true)
try FileManager.default.createDirectory(at: directory,withIntermediateDirectories: true)
func image(_ frame: Int) -> CGImage {
    let c = CGContext(data: nil,width: 240,height: 240,bitsPerComponent: 8,bytesPerRow: 960,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.setFillColor(CGColor(red: 0.94,green: 0.76,blue: 0.48,alpha: 1))
    c.fillEllipse(in: CGRect(x: 40,y: 50,width: 160,height: 160))
    c.setFillColor(CGColor(red: 0.08,green: 0.1,blue: 0.13,alpha: 1))
    c.fillEllipse(in: CGRect(x: 80,y: 140,width: 14,height: frame == 1 ? 4 : 16))
    c.fillEllipse(in: CGRect(x: 146,y: 140,width: 14,height: frame == 1 ? 4 : 16))
    c.setStrokeColor(CGColor(red: 0.08,green: 0.1,blue: 0.13,alpha: 1)); c.setLineWidth(6)
    c.move(to: CGPoint(x: 89,y: 108)); c.addQuadCurve(to: CGPoint(x: 151,y: 108),control: CGPoint(x: 120,y: 76)); c.strokePath()
    c.setFillColor(CGColor(red: 0.45,green: 0.64,blue: 0.55,alpha: 1))
    c.fill(CGRect(x: 60,y: 20,width: 120,height: 40))
    // Semi-transparent corner marker detects wrong premultiplication and orientation.
    c.setFillColor(CGColor(red: 1,green: 0,blue: 0,alpha: 0.5)); c.fill(CGRect(x: 5,y: 215,width: 20,height: 20))
    return c.makeImage()!
}
let png = CGImageDestinationCreateWithURL(directory.appendingPathComponent("transparent-reminder.png") as CFURL,UTType.png.identifier as CFString,1,nil)!
CGImageDestinationAddImage(png,image(0),nil); precondition(CGImageDestinationFinalize(png))
let gif = CGImageDestinationCreateWithURL(directory.appendingPathComponent("blinking-reminder.gif") as CFURL,UTType.gif.identifier as CFString,3,nil)!
CGImageDestinationSetProperties(gif,[kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
for i in 0..<3 {
    CGImageDestinationAddImage(gif,image(i),[kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: i == 0 ? 0.15 : i == 1 ? 0.2 : 0.8]] as CFDictionary)
}
precondition(CGImageDestinationFinalize(gif))
print("Created transparent PNG and unequal-duration GIF fixtures at \(directory.path)")
