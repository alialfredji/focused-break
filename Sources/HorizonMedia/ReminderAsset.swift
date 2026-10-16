import AppKit
import ImageIO
import UniformTypeIdentifiers
import HorizonCore

/// Immutable decoded frames, shared by every renderer. No per-frame disk I/O.
public final class ReminderAsset {
    public let id = UUID()
    public let name: String
    public let frames: [CGImage]
    public let durations: [Double]
    public var aspect: Double { Double(frames[0].width)/Double(frames[0].height) }
    public var isAnimated: Bool { frames.count > 1 }
    public func frameIndex(time: Double, reducedMotion: Bool) -> Int {
        AnimationTimeline.frame(at: time,durations: durations,reducedMotion: reducedMotion)
    }
    private init(name: String,frames: [CGImage],durations: [Double]) {
        self.name = name; self.frames = frames; self.durations = durations
    }
    private static func failure(_ message: String) -> NSError {
        NSError(domain: "ReminderAsset",code: 1,userInfo: [NSLocalizedDescriptionKey: message])
    }
    public static func load(data: Data,name: String) throws -> ReminderAsset {
        guard data.count <= 25*1024*1024 else { throw failure("Choose an image or GIF smaller than 25 MB.") }
        guard let source = CGImageSourceCreateWithData(data as CFData,nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source,0,nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0, width <= 16384, height <= 16384 else {
            throw failure("This image could not be decoded. Choose PNG, JPEG, HEIC or GIF.")
        }
        let gif = (CGImageSourceGetType(source) as String?) == UTType.gif.identifier
        let count = gif ? CGImageSourceGetCount(source) : 1
        guard count > 0, count <= 300,
              Double(width)*Double(height)*4*Double(count) <= 128*1024*1024 else {
            throw failure("This image needs too much decoded memory. Use a smaller image or a shorter GIF (up to 300 frames / 128 MB decoded).")
        }
        var frames: [CGImage] = [], durations: [Double] = []
        // AppKit handles GIF disposal and frame composition, including partial frames.
        let bitmap = gif ? NSBitmapImageRep(data: data) : nil
        if gif && bitmap == nil { throw failure("The GIF could not be decoded.") }
        for index in 0..<count {
            let image: CGImage
            if let bitmap {
                bitmap.setProperty(.currentFrame,withValue: index)
                guard let frame = bitmap.cgImage else { throw failure("A GIF frame could not be decoded.") }
                image = frame
                let props = CGImageSourceCopyPropertiesAtIndex(source,index,nil) as? [CFString: Any]
                let timing = props?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
                let duration = (timing?[kCGImagePropertyGIFUnclampedDelayTime] as? Double)
                    ?? (timing?[kCGImagePropertyGIFDelayTime] as? Double) ?? 0.1
                durations.append(duration.isFinite && duration >= 0.02 ? duration : 0.1)
            } else {
                let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,kCGImageSourceThumbnailMaxPixelSize: 1024]
                guard let frame = CGImageSourceCreateThumbnailAtIndex(source,0,options as CFDictionary) else {
                    throw failure("The image could not be decoded.")
                }
                image = frame; durations.append(0.1)
            }
            let scale = min(1,1024/Double(max(image.width,image.height)))
            let w = max(1,Int(Double(image.width)*scale)), h = max(1,Int(Double(image.height)*scale))
            guard let context = CGContext(data: nil,width: w,height: h,bitsPerComponent: 8,bytesPerRow: w*4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                throw failure("Not enough memory to load this image.")
            }
            context.interpolationQuality = .high
            context.draw(image,in: CGRect(x: 0,y: 0,width: w,height: h))
            guard let copy = context.makeImage() else { throw failure("Cannot prepare this image.") }
            frames.append(copy)
        }
        return ReminderAsset(name: name,frames: frames,durations: durations)
    }
    public static func read(url: URL,name: String? = nil) throws -> (asset: ReminderAsset,data: Data) {
        let length = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard length <= 25*1024*1024 else { throw failure("Choose an image or GIF smaller than 25 MB.") }
        let data = try Data(contentsOf: url,options: .mappedIfSafe)
        return (try load(data: data,name: name ?? url.lastPathComponent),data)
    }
}
