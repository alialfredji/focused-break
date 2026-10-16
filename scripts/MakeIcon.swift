import AppKit
let directory = URL(fileURLWithPath: CommandLine.arguments[1])
let sourceURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("assets/FocusedBreakIcon.png")
guard let artwork = NSImage(contentsOf: sourceURL) else {
    fatalError("Missing icon artwork: \(sourceURL.path)")
}
try FileManager.default.createDirectory(at: directory,withIntermediateDirectories: true)
for size in [16,32,128,256,512] {
    for scale in [1,2] {
        let px = size*scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil,pixelsWide: px,pixelsHigh: px,bitsPerSample: 8,samplesPerPixel: 4,hasAlpha: true,isPlanar: false,colorSpaceName: .deviceRGB,bytesPerRow: 0,bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .high
        artwork.draw(in: NSRect(x: 0,y: 0,width: px,height: px),from: .zero,operation: .copy,fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        let name="icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try rep.representation(using: .png,properties: [:])!.write(to: directory.appendingPathComponent(name))
    }
}
