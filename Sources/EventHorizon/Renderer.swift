import AppKit
import MetalKit
import SwiftUI
import ScreenCaptureKit
import CoreMedia
import HorizonCore
import HorizonMedia

struct RenderParameters {
    var progress: Double = 0.55
    var time: Double = 0
    var effect: EffectSettings = .strong
    var background: PreviewBackground = .workspace
    var reducedMotion: Bool = false
    var movementTime: Double = 0
    var asset: ReminderAsset? = nil
    var lensReach: Double = 1
    var rimBrightness: Double = 0.8
    var rimWidth: Double = 0.045
}

struct RenderUniforms {
    var resolution: SIMD2<Float>
    var time: Float
    var progress: Float
    var size: Float
    var gravity: Float
    var speed: Float
    var travel: Float
    var preview: Float
    var textureMode: Float
    var reducedMotion: Float
    var movementTime: Float
    var center: SIMD2<Float>
    var radius: Float
    var customImage: Float
    var assetAspect: Float
    var lensReach: Float
    var rimBrightness: Float
    var rimWidth: Float
}

/// Bound fragment work independently of the display's Retina backing scale.
private final class EffectMetalView: MTKView {
    var pixelLimit = CGSize(width: 1920,height: 1200)
    override func layout() {
        super.layout()
        guard bounds.width > 0, bounds.height > 0 else { return }
        let scale = min(window?.backingScaleFactor ?? 2,pixelLimit.width/bounds.width,pixelLimit.height/bounds.height)
        let target = CGSize(width: max(1,round(bounds.width*scale)),height: max(1,round(bounds.height*scale)))
        if drawableSize != target { drawableSize = target }
    }
}

final class BlackHoleRenderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    private let queue: MTLCommandQueue
    private let renderQueue = DispatchQueue(label: "EventHorizon.render",qos: .userInteractive)
    private let inFlight = DispatchSemaphore(value: 3)
    private let pipeline: MTLRenderPipelineState
    private let fallback: MTLTexture
    private var cache: CVMetalTextureCache?
    private var capturedTexture: MTLTexture?
    private var capturedBuffer: CVMetalTexture?
    private var capturedFrames = 0
    private var assetTexture: MTLTexture?
    private var assetKey: String?
    private var dynamics = RenderDynamics()
    private var lastFrame: Double?
    private var frameIntervals: [Double] = []
    private var gpuDurations: [Double] = []
    private weak var metalView: MTKView?
    var parameters: () -> RenderParameters = { RenderParameters() }
    let isPreview: Bool
    var hasCapturedFrame: Bool { capturedTexture != nil }

    init(preview: Bool) throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            throw NSError(domain: "EventHorizon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Metal is unavailable on this Mac."])
        }
        self.device = device; self.queue = queue; isPreview = preview
        let resourceBundle = Bundle.main.bundleURL.pathExtension == "app" ? Bundle.main : Bundle.module
        guard let url = resourceBundle.url(forResource: "BlackHole", withExtension: "metal") else {
            throw NSError(domain: "EventHorizon",code: 2,userInfo: [NSLocalizedDescriptionKey: "BlackHole.metal is missing from the app resources. Rebuild the app."])
        }
        let library = try device.makeLibrary(source: String(contentsOf: url), options: nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "vertexMain")
        descriptor.fragmentFunction = library.makeFunction(name: "fragmentMain")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        fallback = try Self.workspaceTexture(device: device)
        super.init()
        CVMetalTextureCacheCreate(nil, nil, device, nil, &cache)
    }

    func makeView(frame: NSRect = .zero) -> MTKView {
        let view = EffectMetalView(frame: frame, device: device)
        view.autoResizeDrawable = false
        view.pixelLimit = isPreview ? CGSize(width: 1440,height: 900) : CGSize(width: 1920,height: 1200)
        if !isPreview && NSScreen.screens.count > 1 {
            let scale = 1/sqrt(Double(NSScreen.screens.count))
            view.pixelLimit = CGSize(width: 1920*scale,height: 1200*scale)
        }
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColorMake(0, 0, 0, 0)
        view.layer?.isOpaque = false
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        // MTKView supplies the frame cadence. Avoid a second blocking vsync wait
        // when displays have different refresh rates (for example 120 Hz / 60 Hz).
        (view.layer as? CAMetalLayer)?.displaySyncEnabled = false
        view.preferredFramesPerSecond = 60
        view.delegate = self
        metalView = view
        return view
    }
    func setDesktopActive(_ active: Bool) { metalView?.preferredFramesPerSecond = active ? 30 : 60 }
    func inheritMotion(from renderer: BlackHoleRenderer) { dynamics = renderer.dynamics }

    func receive(_ buffer: CVPixelBuffer) {
        guard let cache else { return }
        var result: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(nil, cache, buffer, nil, .bgra8Unorm,
            CVPixelBufferGetWidth(buffer), CVPixelBufferGetHeight(buffer), 0, &result)
        if status == kCVReturnSuccess, let result, let texture = CVMetalTextureGetTexture(result) {
            capturedBuffer = result; capturedTexture = texture; capturedFrames += 1
        }
    }
    func clearCapture() { capturedTexture = nil; capturedBuffer = nil }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    func draw(in view: MTKView) {
        guard view.window?.isVisible == true, view.drawableSize.width > 0, view.drawableSize.height > 0,
              let layer = view.layer as? CAMetalLayer,
              inFlight.wait(timeout: .now()) == .success else { return }
        let frameBuffer = capturedBuffer
        let texture = capturedTexture ?? fallback
        let now = ProcessInfo.processInfo.systemUptime
        if frameIntervals.count < 720, let lastFrame { frameIntervals.append(now-lastFrame) }
        lastFrame = now
        let uniforms = makeUniforms(size: view.drawableSize,live: true)
        let imageTexture = assetTexture ?? fallback
        // Drawable acquisition may block at display refresh. Keep that off the UI
        // thread so one display cannot stall the other display, capture, or controls.
        renderQueue.async { [self] in
            autoreleasepool {
                guard let drawable = layer.nextDrawable(), let command = queue.makeCommandBuffer() else { inFlight.signal(); return }
                let descriptor = MTLRenderPassDescriptor()
                descriptor.colorAttachments[0].texture = drawable.texture
                descriptor.colorAttachments[0].loadAction = .clear
                descriptor.colorAttachments[0].storeAction = .store
                descriptor.colorAttachments[0].clearColor = MTLClearColorMake(0,0,0,0)
                guard let encoder = command.makeRenderCommandEncoder(descriptor: descriptor) else { inFlight.signal(); return }
                var uniforms = uniforms
                encoder.setRenderPipelineState(pipeline)
                encoder.setFragmentBytes(&uniforms,length: MemoryLayout<RenderUniforms>.stride,index: 0)
                encoder.setFragmentTexture(texture,index: 0)
                encoder.setFragmentTexture(imageTexture,index: 1)
                encoder.drawPrimitives(type: .triangle,vertexStart: 0,vertexCount: 3)
                encoder.endEncoding()
                command.addCompletedHandler { [self] command in
                    _ = frameBuffer
                    inFlight.signal()
                    let gpu = command.gpuEndTime-command.gpuStartTime
                    DispatchQueue.main.async { if self.gpuDurations.count < 720 { self.gpuDurations.append(gpu) } }
                }
                command.present(drawable); command.commit()
            }
        }
    }

    func performanceReport() -> [String: Double] {
        let intervals = Array(frameIntervals.dropFirst(60)).sorted()
        let gpu = Array(gpuDurations.dropFirst(60)).sorted()
        guard !intervals.isEmpty else { return ["frames":Double(frameIntervals.count),"capturedFrames":Double(capturedFrames)] }
        return ["frames":Double(intervals.count),"capturedFrames":Double(capturedFrames),"fps":Double(intervals.count)/intervals.reduce(0,+),
            "frameP95ms":intervals[Int(Double(intervals.count-1)*0.95)]*1000,
            "gpuP95ms":gpu.isEmpty ? 0 : gpu[Int(Double(gpu.count-1)*0.95)]*1000]
    }
    private func makeUniforms(size: CGSize,live: Bool = false) -> RenderUniforms {
        let p = parameters()
        if let asset = p.asset {
            let frame = asset.frameIndex(time: p.time,reducedMotion: p.reducedMotion)
            let key = "\(asset.id)-\(frame)"
            if key != assetKey {
                assetTexture = try? MTKTextureLoader(device: device).newTexture(cgImage: asset.frames[frame],
                    options: [.SRGB: false,.origin: MTKTextureLoader.Origin.topLeft])
                assetKey = key
            }
        } else { assetTexture = nil; assetKey = nil }
        var e = p.effect.clamped
        var spin = p.time*e.speed, travel = p.movementTime*e.travelSpeed
        if live {
            dynamics.sample(target: e,source: p.time,travel: p.movementTime,wall: ProcessInfo.processInfo.systemUptime,reduced: p.reducedMotion)
            e = dynamics.settings ?? e; spin = dynamics.spin; travel = dynamics.travelPhase
        }
        let mode: Float
        if !isPreview { mode = capturedTexture == nil ? 0 : 1 }
        else {
            switch p.background {
            case .space: mode = 0
            case .workspace: mode = 1
            case .grid: mode = 2
            case .desktop: mode = capturedTexture == nil ? 2 : 1
            }
        }
        let geometry = LensGeometry(aspect: size.width/max(1,size.height),size: e.size,growth: p.progress,
            travel: e.travel,phase: p.reducedMotion ? 0 : travel)
        return RenderUniforms(resolution: SIMD2(Float(size.width),Float(size.height)),
            time: Float(spin),progress: Float(p.progress),size: Float(e.size),gravity: Float(e.gravity),
            speed: Float(e.speed),travel: Float(e.travel),preview: isPreview ? 1 : 0,
            textureMode: mode,reducedMotion: p.reducedMotion ? 1 : 0,movementTime: Float(travel),
            center: SIMD2(Float(geometry.centerX),Float(geometry.centerY)),radius: Float(geometry.radius),
            customImage: assetTexture == nil ? 0 : 1,assetAspect: Float(p.asset?.aspect ?? 1),
            lensReach: Float(p.lensReach),rimBrightness: Float(p.rimBrightness),rimWidth: Float(p.rimWidth))
    }

    /// Offscreen shader regression artifacts use the shipping render pipeline.
    func exportPNG(to url: URL, width: Int = 1280, height: Int = 800) throws {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,width: width,height: height,mipmapped: false)
        descriptor.usage = [.renderTarget,.shaderRead]; descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor), let command = queue.makeCommandBuffer() else {
            throw NSError(domain: "EventHorizon",code: 3,userInfo: [NSLocalizedDescriptionKey: "Cannot create render target"])
        }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear; pass.colorAttachments[0].storeAction = .store
        guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return }
        var uniforms = makeUniforms(size: CGSize(width: width,height: height))
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&uniforms,length: MemoryLayout<RenderUniforms>.stride,index: 0)
        encoder.setFragmentTexture(capturedTexture ?? fallback,index: 0)
        encoder.setFragmentTexture(assetTexture ?? fallback,index: 1)
        encoder.drawPrimitives(type: .triangle,vertexStart: 0,vertexCount: 3); encoder.endEncoding()
        command.commit(); command.waitUntilCompleted()
        if let error = command.error { throw error }
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil,pixelsWide: width,pixelsHigh: height,bitsPerSample: 8,
            samplesPerPixel: 4,hasAlpha: true,isPlanar: false,colorSpaceName: .deviceRGB,bytesPerRow: width*4,bitsPerPixel: 32)!
        let bytes = rep.bitmapData!
        texture.getBytes(bytes,bytesPerRow: width*4,from: MTLRegionMake2D(0,0,width,height),mipmapLevel: 0)
        for i in stride(from: 0,to: width*height*4,by: 4) {
            let b = bytes[i]; bytes[i] = bytes[i+2]; bytes[i+2] = b
        }
        try rep.representation(using: .png,properties: [:])!.write(to: url)
    }

    private static func workspaceTexture(device: MTLDevice) throws -> MTLTexture {
        let width=1440, height=900
        let rep=NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep: rep)
        NSColor(calibratedRed: 0.045, green: 0.052, blue: 0.064, alpha: 1).setFill()
        NSRect(x: 0,y: 0,width: width,height: height).fill()
        NSColor(calibratedWhite: 0.085,alpha: 1).setFill()
        NSRect(x: 0,y: height-56,width: width,height: 56).fill()
        NSRect(x: 0,y: 0,width: 230,height: height-56).fill()
        func text(_ value: String,_ x: Int,_ y: Int,_ color: NSColor,_ size: CGFloat = 20) {
            (value as NSString).draw(at: NSPoint(x: x,y: y),withAttributes: [.font: NSFont.monospacedSystemFont(ofSize: size,weight: .regular),.foregroundColor: color])
        }
        text("Session.swift",270,height-38,.lightGray)
        for (i,name) in ["EXPLORER","","Sources","  HorizonCore","    Session.swift","    Effect.swift","","Tests","Package.swift","README.md"].enumerated() {
            text(name,20,height-110-i*32,NSColor(calibratedWhite: 0.5,alpha: 1),17)
        }
        let lines = ["import Foundation", "", "public struct Session {", "    enum Phase {", "        case ready, focus, rest, complete", "    }", "", "    private(set) var phase: Phase = .ready", "    private(set) var elapsed: TimeInterval = 0", "", "    var remaining: TimeInterval {", "        max(0, duration - elapsed)", "    }", "", "    mutating func tick(now: TimeInterval) {", "        guard isActive, !isPaused else { return }", "        elapsed += max(0, now - lastTime)", "        lastTime = now", "", "        if elapsed >= duration {", "            phase = phase == .focus ? .rest : .complete", "            elapsed = 0", "        }", "    }", "}"]
        for (i,line) in lines.enumerated() {
            let color = line.contains("func") || line.contains("var") || line.contains("struct") ? NSColor(calibratedRed: 0.62,green: 0.76,blue: 0.92,alpha: 1) : NSColor(calibratedWhite: 0.68,alpha: 1)
            text(String(format: "%2d",i+1),250,height-105-i*30,NSColor(calibratedWhite: 0.31,alpha: 1),18)
            text(line,305,height-105-i*30,color)
        }
        NSGraphicsContext.restoreGraphicsState()
        return try MTKTextureLoader(device: device).newTexture(cgImage: rep.cgImage!, options: [.SRGB: false, .origin: MTKTextureLoader.Origin.topLeft])
    }
}

/// Frames are transient GPU inputs. No recording, audio capture, file output, or network.
final class DesktopCapture: NSObject, SCStreamOutput, SCStreamDelegate {
    private var stream: SCStream?
    private var wanted = true
    weak var renderer: BlackHoleRenderer?
    var onError: (String) -> Void = { _ in }
    var onReady: () -> Void = {}

    @MainActor func start(displayID: CGDirectDisplayID, renderer: BlackHoleRenderer) async {
        self.renderer = renderer
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard wanted, let display = content.displays.first(where: { $0.displayID == displayID }) else { return }
            let ownApps = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
            let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])
            if #available(macOS 14.2, *) { filter.includeMenuBar = true }
            let configuration = SCStreamConfiguration()
            let displayScale = renderer.isPreview ? 1 : 1/sqrt(Double(NSScreen.screens.count))
            let scale = min(1.0,1920.0*displayScale/Double(display.width),1200.0*displayScale/Double(display.height))
            configuration.width = Int(Double(display.width)*scale)
            configuration.height = Int(Double(display.height)*scale)
            configuration.minimumFrameInterval = CMTime(value: 1,timescale: 60)
            configuration.queueDepth = 3
            configuration.pixelFormat = kCVPixelFormatType_32BGRA
            configuration.showsCursor = false
            configuration.capturesAudio = false
            let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
            try stream.addStreamOutput(self,type: .screen,sampleHandlerQueue: .main)
            self.stream = stream
            try await stream.startCapture()
            if !wanted { try? await stream.stopCapture() }
        } catch {
            if wanted { onError("Desktop lens unavailable: \(error.localizedDescription)") }
        }
    }
    func stop() {
        wanted = false
        renderer?.clearCapture()
        let old = stream; stream = nil
        Task { try? await old?.stopCapture() }
    }
    func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard wanted, type == .screen, buffer.isValid, let image = buffer.imageBuffer, let renderer else { return }
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(buffer,createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let rawStatus = attachments.first?[.status] as? Int,
              SCFrameStatus(rawValue: rawStatus) == .complete else { return }
        let hadFrame = renderer.hasCapturedFrame
        renderer.receive(image)
        if !hadFrame && renderer.hasCapturedFrame { onReady() }
    }
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.wanted else { return }
            self.renderer?.clearCapture(); self.onError("Desktop lens stopped: \(error.localizedDescription)")
        }
    }
}

struct HolePreview: NSViewRepresentable {
    @ObservedObject var model: AppModel
    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator { var renderer: BlackHoleRenderer?; weak var model: AppModel? }
    func makeNSView(context: Context) -> NSView {
        do {
            let renderer = try BlackHoleRenderer(preview: true)
            renderer.parameters = { [weak model] in model?.renderParameters(preview: true) ?? RenderParameters() }
            context.coordinator.renderer=renderer
            context.coordinator.model=model
            DispatchQueue.main.async { model.attachPreview(renderer) }
            return renderer.makeView()
        } catch {
            DispatchQueue.main.async { model.error = error.localizedDescription }
            return NSTextField(labelWithString: "The preview could not start. \(error.localizedDescription)")
        }
    }
    func updateNSView(_ nsView: NSView,context: Context) {}
    static func dismantleNSView(_ nsView: NSView,coordinator: Coordinator) {
        coordinator.model?.detachPreview()
        (nsView as? MTKView)?.isPaused = true
        (nsView as? MTKView)?.delegate = nil
        coordinator.renderer = nil
    }
}
