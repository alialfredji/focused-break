import AppKit
import SwiftUI
import HorizonCore
import MetalKit
import ScreenCaptureKit
import HorizonMedia
import UniformTypeIdentifiers

enum PreviewBackground: Int, CaseIterable {
    case workspace, grid, space, desktop
    var label: String {
        switch self {
        case .workspace: return "Workspace"
        case .grid: return "Grid"
        case .space: return "Space"
        case .desktop: return "Live desktop"
        }
    }
}

enum BreakAppearance: String { case blackHole, haveABreak, custom }

final class AppModel: ObservableObject {
    @Published private(set) var session = Session()
    @Published var minimumBreakSeconds = min(300,max(5,UserDefaults.standard.object(forKey: "minimumBreakSeconds") as? Int ?? 5)) {
        didSet { UserDefaults.standard.set(minimumBreakSeconds,forKey: "minimumBreakSeconds") }
    }
    @Published var focusMinutes = UserDefaults.standard.object(forKey: "focusMinutes") as? Int ?? 25 {
        didSet { UserDefaults.standard.set(focusMinutes,forKey: "focusMinutes") }
    }
    @Published var breakMinutes = UserDefaults.standard.object(forKey: "breakMinutes") as? Int ?? 5 {
        didSet { UserDefaults.standard.set(breakMinutes,forKey: "breakMinutes") }
    }
    @Published var effect: EffectSettings = {
        guard let data = UserDefaults.standard.data(forKey: "effect.v3") ?? UserDefaults.standard.data(forKey: "effect.v2"),
              let settings = try? JSONDecoder().decode(EffectSettings.self,from: data) else { return .standard }
        return settings.clamped
    }() {
        didSet {
            if let data = try? JSONEncoder().encode(effect.clamped) { UserDefaults.standard.set(data,forKey: "effect.v3") }
        }
    }
    @Published var reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    @Published var customAppearance = UserDefaults.standard.object(forKey: "customAppearance") as? Bool ?? true {
        didSet { UserDefaults.standard.set(customAppearance,forKey: "customAppearance") }
    }
    @Published private(set) var reminderAsset: ReminderAsset?
    @Published private(set) var usingDefaultImage = true
    var appearance: BreakAppearance {
        !customAppearance ? .blackHole : usingDefaultImage ? .haveABreak : .custom
    }
    func resetEffectDefaults() {
        effect = .standard
        lensReach = 1
        rimBrightness = 1.2
        rimWidth = 0.045
    }
    func selectAppearance(_ appearance: BreakAppearance) {
        guard !importingAsset else { return }
        if appearance == .blackHole { customAppearance = false; return }
        if appearance == .custom && !FileManager.default.fileExists(atPath: assetDirectory.appendingPathComponent("reminder.asset").path) {
            chooseAsset(); return
        }
        usingDefaultImage = appearance == .haveABreak
        UserDefaults.standard.set(usingDefaultImage,forKey: "usingDefaultImage")
        customAppearance = true
        restoreAsset()
    }
    @Published private(set) var importingAsset = false
    @Published var lensReach: Double = 1 {
        didSet { UserDefaults.standard.set(lensReach,forKey: "lensReach") }
    }
    @Published var rimBrightness: Double = 1.2 {
        didSet { UserDefaults.standard.set(rimBrightness,forKey: "rimBrightness") }
    }
    @Published var rimWidth: Double = 0.045 {
        didSet { UserDefaults.standard.set(rimWidth,forKey: "rimWidth") }
    }
    private let importQueue = DispatchQueue(label: "EventHorizon.assets",qos: .userInitiated)
    private var assetDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory,in: .userDomainMask)[0]
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "EventHorizon.Development",isDirectory: true)
    }
    @Published var previewBackground: PreviewBackground = .desktop {
        didSet { updatePreviewCapture() }
    }
    @Published private(set) var previewPlaying = true
    @Published var desktopLens = false
    @Published var lensStatus = "Off"
    @Published var previewCaptureStatus = ""
    @Published var error: String?
    @Published var notice: String?
    @Published private(set) var testEndsAt: TimeInterval?
    @Published private(set) var completionDismissed = false
    weak var previewRenderer: BlackHoleRenderer?
    var onUpdate: () -> Void = {}
    var onBreakStarted: () -> Void = {}
    var onBreakCompleted: () -> Void = {}
    private var completionPresented = false
    private var assetPanel: NSOpenPanel?
    @Published var assetError: String?
    private var timer: Timer?
    private var overlays: [Overlay] = []
    private var breakPanel: NSPanel?
    private var sleepObserver: NSObjectProtocol?
    private var screenObserver: NSObjectProtocol?
    private var accessibilityObserver: NSObjectProtocol?
    private var permissionTask: Task<Void,Never>?
    private var previewCapture: DesktopCapture?
    private var previewTask: Task<Void,Never>?
    private var lensReady = false
    private var previewOffset: Double = 0
    private var previewAnchor = ProcessInfo.processInfo.systemUptime

    init() {
        func saved(_ key: String,_ fallback: Double,_ range: ClosedRange<Double>) -> Double {
            let n = UserDefaults.standard.object(forKey: key) as? Double ?? fallback
            return n.isFinite ? min(range.upperBound,max(range.lowerBound,n)) : fallback
        }
        lensReach = saved("lensReach",1,0.5...2)
        rimBrightness = saved("rimBrightness",1.2,0...2)
        rimWidth = saved("rimWidth",0.045,0.015...0.15)
        if !UserDefaults.standard.bool(forKey: "screenshotEffectDefaults.v1") {
            resetEffectDefaults()
            UserDefaults.standard.set(true,forKey: "screenshotEffectDefaults.v1")
        }
        usingDefaultImage = UserDefaults.standard.object(forKey: "usingDefaultImage") as? Bool
            ?? !FileManager.default.fileExists(atPath: assetDirectory.appendingPathComponent("reminder.asset").path)
        restoreAsset()
        if !TimerOptions.focus.contains(focusMinutes) { focusMinutes = 25 }
        if !TimerOptions.rest.contains(breakMinutes) { breakMinutes = 5 }
        let timer = Timer(timeInterval: 1,repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer,forMode: .common); self.timer = timer
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification,object: nil,queue: .main) { [weak self] _ in
            guard let self else { return }
            self.testEndsAt = nil
            if self.session.isActive {
                self.session.pause(now: self.now)
                self.notice = "Paused during sleep."
            }
            self.stopPreviewCapture()
            self.synchronize()
        }
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,object: nil,queue: .main) { [weak self] _ in
            self?.hideOverlays(); self?.updatePreviewCapture(); self?.synchronize()
        }
        accessibilityObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,object: nil,queue: .main) { [weak self] _ in
            self?.reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        }
        if UserDefaults.standard.bool(forKey: "desktopDistortionEnabled") { setDesktopLens(true) }
    }
    private var now: TimeInterval { ProcessInfo.processInfo.systemUptime }
    var isTesting: Bool { testEndsAt != nil }
    var breakLockRemaining: Int { session.breakLockRemaining(now: now) }
    var breakLocked: Bool { breakLockRemaining > 0 }
    var testRemaining: Int { Int(ceil(max(0,(testEndsAt ?? now)-now))) }
    var captureIsLive: Bool { !overlays.isEmpty && overlays.allSatisfy { $0.captureStatus == "Live" && $0.renderer.hasCapturedFrame } }
    var desktopTestTitle: String {
        if isTesting { return "Stop desktop test · \(testRemaining)s" }
        return desktopLens ? "Test gravity on desktop · 10s" : "Test reminder only · 10s"
    }
    var previewTime: Double { previewOffset + (previewPlaying ? now-previewAnchor : 0) }
    var previewSample: PreviewSample { PreviewCycle.effect(at: previewTime) }
    var clockText: String {
        let seconds = session.isActive ? Int(ceil(session.remaining)) : focusMinutes*60
        return String(format: "%02d:%02d",seconds/60,seconds%60)
    }
    var phaseTitle: String {
        if isTesting { return "Desktop test · \(testRemaining)s" }
        if session.isPaused { return "Paused" }
        switch session.phase {
        case .ready: return "Ready"
        case .focus: return session.isDemo ? "Demo · focus" : "Focus"
        case .rest: return session.isDemo ? "Demo · break" : "Break"
        case .complete: return "Break over"
        }
    }
    func renderParameters(preview: Bool) -> RenderParameters {
        if !preview, let end = testEndsAt {
            let elapsed = max(0,now-(end-DesktopTestTimeline.duration))
            let sample = DesktopTestTimeline.sample(elapsed: elapsed)
            return RenderParameters(progress: sample.growth,time: elapsed,effect: effect.clamped,
                background: previewBackground,reducedMotion: reduceMotion,movementTime: sample.movementTime,
                asset: customAppearance ? reminderAsset : nil,lensReach: lensReach,rimBrightness: rimBrightness,rimWidth: rimWidth)
        }
        if !preview && !isTesting {
            let elapsed = session.renderElapsed(now: now)
            let visual = session.showsDesktopEffect ? BreakEffect.sample(elapsed: elapsed,duration: session.restDuration) : BreakVisual(growth: 0,movementTime: 0)
            return RenderParameters(progress: visual.growth,time: elapsed,effect: effect.clamped,
                background: previewBackground,reducedMotion: reduceMotion,movementTime: visual.movementTime,
                asset: customAppearance ? reminderAsset : nil,lensReach: lensReach,rimBrightness: rimBrightness,rimWidth: rimWidth)
        }
        let sample = previewSample
        return RenderParameters(progress: sample.growth,
            time: previewTime, effect: effect.clamped,
            background: previewBackground, reducedMotion: reduceMotion,movementTime: sample.movementTime,
            asset: customAppearance ? reminderAsset : nil,lensReach: lensReach,rimBrightness: rimBrightness,rimWidth: rimWidth)
    }
    func chooseAsset() {
        guard !importingAsset, assetPanel == nil else { return }
        let panel = NSOpenPanel()
        assetPanel = panel
        panel.title = "Choose a reminder image or GIF"
        panel.prompt = "Use image"
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false; panel.canChooseDirectories = false
        panel.canChooseFiles = true
        NSApp.activate(ignoringOtherApps: true)
        let completion: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            self?.assetPanel = nil
            guard response == .OK, let url = panel.url else { return }
            self?.importAsset(url)
        }
        if let window = NSApp.keyWindow { panel.beginSheetModal(for: window,completionHandler: completion) }
        else { panel.begin(completionHandler: completion) }
    }
    func importAsset(_ url: URL) {
        guard !importingAsset else { return }
        importingAsset = true; error = nil; assetError = nil
        let destination = assetDirectory
        importQueue.async { [weak self] in
            do {
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let result = try ReminderAsset.read(url: url)
                try FileManager.default.createDirectory(at: destination,withIntermediateDirectories: true)
                try result.data.write(to: destination.appendingPathComponent("reminder.asset"),options: .atomic)
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.reminderAsset = result.asset; self.customAppearance = true; self.importingAsset = false
                    self.usingDefaultImage = false
                    UserDefaults.standard.set(false,forKey: "usingDefaultImage")
                    UserDefaults.standard.set(result.asset.name,forKey: "reminderName")
                    self.replayPreview(); self.notice = nil
                }
            } catch {
                DispatchQueue.main.async { self?.importingAsset = false; self?.assetError = error.localizedDescription }
            }
        }
    }
    private func restoreAsset() {
        let bundled = usingDefaultImage
        let url = bundled
            ? (Bundle.main.url(forResource: "HaveABreak",withExtension: "gif") ?? Bundle.module.url(forResource: "HaveABreak",withExtension: "gif"))
            : assetDirectory.appendingPathComponent("reminder.asset")
        guard let url else { assetError = "The included break image is missing."; return }
        importingAsset = true
        let name = bundled ? "Have a break" : UserDefaults.standard.string(forKey: "reminderName") ?? "Saved image"
        importQueue.async { [weak self] in
            do {
                let asset = try ReminderAsset.read(url: url,name: name).asset
                DispatchQueue.main.async { self?.reminderAsset = asset; self?.importingAsset = false }
            } catch {
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.importingAsset = false
                    if !bundled {
                        self.usingDefaultImage = true
                        UserDefaults.standard.set(true,forKey: "usingDefaultImage")
                        self.restoreAsset()
                    } else {
                        self.customAppearance = false
                    }
                    self.assetError = "Could not load image: \(error.localizedDescription)"
                }
            }
        }
    }
    func removeAsset() {
        guard !importingAsset else { return }
        do {
            let url = assetDirectory.appendingPathComponent("reminder.asset")
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
            reminderAsset = nil; customAppearance = true; usingDefaultImage = true
            UserDefaults.standard.set(true,forKey: "usingDefaultImage")
            UserDefaults.standard.removeObject(forKey: "reminderName")
            restoreAsset()
        } catch { self.error = "Could not remove the saved image: \(error.localizedDescription)" }
    }
    func togglePreview() {
        previewOffset = previewTime; previewAnchor = now
        previewPlaying.toggle()
    }
    func replayPreview() { previewOffset = 0; previewAnchor = now; previewPlaying = true }
    func testOnDesktop() {
        guard !session.isActive else { return }
        guard !desktopLens || lensReady else {
            error = "Gravity cannot run yet. Enable Screen Recording for this app in Privacy Settings, then click Recheck access."
            return
        }
        error = nil; notice = nil
        if !desktopLens { notice = "Reminder-only test: desktop gravity is off. Enable Desktop distortion to bend the background." }
        testEndsAt = now+DesktopTestTimeline.duration
        synchronize()
    }
    func endDesktopTest() {
        if isTesting || testEndsAt != nil {
            let directory = FileManager.default.urls(for: .cachesDirectory,in: .userDomainMask)[0]
                .appendingPathComponent(Bundle.main.bundleIdentifier ?? "EventHorizon")
            try? FileManager.default.createDirectory(at: directory,withIntermediateDirectories: true)
            if let data = try? JSONSerialization.data(withJSONObject: performanceReports(),options: [.sortedKeys,.prettyPrinted]) {
                try? data.write(to: directory.appendingPathComponent("last-desktop-test.json"),options: .atomic)
            }
        }
        testEndsAt = nil; synchronize()
    }
    func performanceReports() -> [String: Any] {
        ["preview": previewRenderer?.performanceReport() ?? [:],
         "desktop": overlays.map { ["displayID": $0.displayID,"capture": $0.captureStatus,"render": $0.renderer.performanceReport()] as [String: Any] },
         "capture": lensStatus]
    }
    func start() {
        guard !session.isActive else { return }
        testEndsAt = nil; error = nil; notice = nil; completionDismissed = false
        session.start(focus: Double(focusMinutes*60),rest: Double(breakMinutes*60),now: now,minimumBreak: Double(minimumBreakSeconds))
        synchronize()
    }
    func togglePause() {
        session.tick(now: now)
        guard !breakLocked || session.isPaused else { synchronize(); return }
        notice = nil
        if session.isPaused { session.resume(now: now) } else { session.pause(now: now) }
        synchronize()
    }
    func takeBreak() { session.takeBreak(now: now); synchronize() }
    func stop() {
        let wasBreak = session.phase == .rest
        session.tick(now: now)
        guard !breakLocked else { synchronize(); return }
        testEndsAt = nil; session.stop(); notice = nil
        synchronize()
        if wasBreak { onBreakCompleted() }
    }
    func dismissCompletion() { completionDismissed = true; synchronize() }
    func tick() {
        if let end = testEndsAt, now >= end { endDesktopTest() }
        if session.isActive { session.tick(now: now) }
        else if isTesting { objectWillChange.send() }
        synchronize()
    }
    func setDesktopLens(_ enabled: Bool) {
        UserDefaults.standard.set(enabled,forKey: "desktopDistortionEnabled")
        permissionTask?.cancel()
        lensReady = false; desktopLens = enabled; error = nil; notice = nil
        lensStatus = enabled ? "Checking access…" : "Off"
        stopPreviewCapture(); hideOverlays(); synchronize()
        guard enabled else { return }
        permissionTask = Task { @MainActor [weak self] in
            do {
                _ = try await SCShareableContent.excludingDesktopWindows(false,onScreenWindowsOnly: true)
                guard !Task.isCancelled, let self, self.desktopLens else { return }
                self.lensReady = true; self.lensStatus = "Ready"
                self.hideOverlays(); self.synchronize(); self.updatePreviewCapture()
            } catch {
                guard !Task.isCancelled, let self else { return }
                self.lensStatus = "Access unavailable"
                self.error = "Desktop gravity is blocked by macOS. Enable Screen Recording for \(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Focused Break") in Privacy Settings, then click Recheck access. \(error.localizedDescription)"
                self.hideOverlays(); self.synchronize()
            }
        }
    }
    func attachPreview(_ renderer: BlackHoleRenderer) {
        previewRenderer = renderer; updatePreviewCapture()
    }
    func detachPreview() { stopPreviewCapture(); previewRenderer = nil }
    private func updatePreviewCapture() {
        stopPreviewCapture()
        guard previewBackground == .desktop, desktopLens, lensReady, let renderer = previewRenderer,
              let screen = NSScreen.main else { return }
        let capture = DesktopCapture()
        previewCaptureStatus = "Connecting…"
        capture.onReady = { [weak self] in self?.previewCaptureStatus = "Live" }
        capture.onError = { [weak self] message in self?.previewCaptureStatus = "Unavailable"; self?.error = message }
        previewCapture = capture
        let displayID = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? CGMainDisplayID()
        previewTask = Task { await capture.start(displayID: displayID,renderer: renderer) }
    }
    private func stopPreviewCapture() {
        previewTask?.cancel(); previewCapture?.stop(); previewCapture = nil
        previewCaptureStatus = ""
    }
    func openPrivacySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
    }
    private func synchronize() {
        if isTesting || session.showsDesktopEffect {
            if overlays.isEmpty {
                if session.showsDesktopEffect { assetPanel?.cancel(nil); onBreakStarted() }
                showOverlays()
            }
        } else if !overlays.isEmpty { hideOverlays() }
        hidePanel()
        onUpdate()
        // Present once after overlays are gone, never again on later timer ticks.
        if session.phase == .complete {
            if !completionPresented {
                completionPresented = true
                onBreakCompleted()
            }
        } else {
            completionPresented = false
        }
    }
    private func showOverlays() {
        previewRenderer?.setDesktopActive(true)
        for screen in NSScreen.screens {
            do {
                let overlay = try Overlay(screen: screen,model: self)
                overlays.append(overlay); overlay.window.orderFrontRegardless()
                if desktopLens && lensReady { overlay.startCapture(model: self) }
            } catch { self.error = "Desktop effect failed: \(error.localizedDescription)" }
        }
    }
    func updateCaptureStatus() {
        guard desktopLens, lensReady, !overlays.isEmpty else { return }
        if captureIsLive { lensStatus = "Live · \(overlays.count) display\(overlays.count == 1 ? "" : "s")" }
        else if overlays.contains(where: { $0.captureStatus == "Stopped" }) { lensStatus = "Capture stopped" }
        else { lensStatus = "Connecting…" }
    }
    private func hideOverlays() {
        previewRenderer?.setDesktopActive(false)
        for overlay in overlays { overlay.close() }
        overlays.removeAll()
        if desktopLens && lensReady { lensStatus = "Ready" }
    }
    private func hidePanel() { breakPanel?.orderOut(nil); breakPanel = nil }
    private func showBreakPanel() {
        guard let screen = NSScreen.main else { return }
        let panel = NSPanel(contentRect: NSRect(x: 0,y: 0,width: 380,height: 110),styleMask: [.borderless,.nonactivatingPanel],backing: .buffered,defer: false)
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue+1)
        panel.collectionBehavior = [.canJoinAllSpaces,.fullScreenAuxiliary]
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = true
        panel.contentView = NSHostingView(rootView: BreakCard(model: self).preferredColorScheme(.light))
        panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.midX-190,y: screen.visibleFrame.minY+48))
        panel.orderFrontRegardless(); breakPanel = panel
    }
    func terminate() {
        timer?.invalidate(); permissionTask?.cancel(); stopPreviewCapture(); hideOverlays(); hidePanel()
    }
}

private final class Overlay {
    let window: NSWindow
    let renderer: BlackHoleRenderer
    let displayID: CGDirectDisplayID
    private var capture: DesktopCapture?
    private var task: Task<Void,Never>?
    private(set) var captureStatus = "Off"
    init(screen: NSScreen,model: AppModel) throws {
        renderer = try BlackHoleRenderer(preview: false)
        displayID = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? CGMainDisplayID()
        window = NSWindow(contentRect: screen.frame,styleMask: .borderless,backing: .buffered,defer: false)
        window.title = "Focused Break Desktop Effect"
        window.isReleasedWhenClosed = false
        window.isOpaque = false; window.backgroundColor = .clear; window.hasShadow = false
        window.ignoresMouseEvents = true
        // Keep the real menu bar and its controls above the desktop effect.
        window.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue-1)
        window.collectionBehavior = [.canJoinAllSpaces,.fullScreenAuxiliary,.stationary,.ignoresCycle]
        renderer.parameters = { [weak model] in model?.renderParameters(preview: false) ?? RenderParameters() }
        window.contentView = renderer.makeView(frame: NSRect(origin: .zero,size: screen.frame.size))
    }
    func startCapture(model: AppModel) {
        let capture = DesktopCapture()
        captureStatus = "Connecting"
        capture.onError = { [weak self,weak model] message in
            self?.captureStatus = "Stopped"; model?.error = message; model?.updateCaptureStatus()
        }
        capture.onReady = { [weak self,weak model] in
            self?.captureStatus = "Live"; model?.updateCaptureStatus()
        }
        self.capture = capture
        model.updateCaptureStatus()
        task = Task { await capture.start(displayID: displayID,renderer: renderer) }
    }
    func close() {
        task?.cancel(); capture?.stop(); capture = nil
        (window.contentView as? MTKView)?.isPaused = true
        (window.contentView as? MTKView)?.delegate = nil
        window.orderOut(nil); window.close()
    }
}
