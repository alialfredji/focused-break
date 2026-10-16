import AppKit
import SwiftUI
import HorizonMedia
import HorizonCore

@main
enum EventHorizonApp {
    static func main() {
        let app = NSApplication.shared
        if let index = CommandLine.arguments.firstIndex(of: "--render-check"), CommandLine.arguments.count > index+1 {
            do {
                let directory = URL(fileURLWithPath: CommandLine.arguments[index+1],isDirectory: true)
                try FileManager.default.createDirectory(at: directory,withIntermediateDirectories: true)
                let renderer = try BlackHoleRenderer(preview: true)
                let cases: [(String,Double,Double,Bool)] = [("early",0.15,4,false),("mid",0.55,4,false),("moved",0.55,8,false),("late",0.85,4,false),("takeover",1,4,false),("reduced-a",0.55,4,true),("reduced-b",0.55,8,true)]
                for (name,progress,time,reduced) in cases {
                    renderer.parameters = { RenderParameters(progress: progress,time: time,reducedMotion: reduced,movementTime: time) }
                    try renderer.exportPNG(to: directory.appendingPathComponent(name+".png"))
                }
                renderer.parameters = { RenderParameters(progress: 0,time: 0) }
                try renderer.exportPNG(to: directory.appendingPathComponent("focus-clear.png"))
                var baseline = RenderParameters(progress: 1,time: 4,movementTime: 4)
                baseline.effect = .strong
                var variants: [(String,RenderParameters)] = [("control-baseline",baseline)]
                for (name,size) in [("size-tiny",0.02),("size-small",0.12),("size-large",1.4),("size-full",4.0)] {
                    var value = baseline; value.effect.size = size; variants.append((name,value))
                }
                var gravity = baseline; gravity.effect.gravity = 0; variants.append(("control-gravity-zero",gravity))
                var speed = baseline; speed.effect.speed = 0; variants.append(("control-speed-zero",speed))
                var travel = baseline; travel.effect.travel = 0; variants.append(("control-travel-zero",travel))
                var highGravity = baseline; highGravity.effect.gravity = 10; variants.append(("gravity-10",highGravity))
                var highSpeed = baseline; highSpeed.effect.speed = 10; variants.append(("animation-10",highSpeed))
                var highTravel = baseline; highTravel.effect.travel = 1; highTravel.effect.travelSpeed = 10; variants.append(("travel-10",highTravel))
                for (name,parameters) in variants {
                    renderer.parameters = { parameters }
                    try renderer.exportPNG(to: directory.appendingPathComponent(name+".png"))
                }
                for (name,width,height) in [("portrait",600,1000),("ultrawide",1600,500)] {
                    var value = baseline; value.effect.size = 1.4; value.effect.travel = 1
                    value.movementTime = 11; value.effect.gravity = 10
                    renderer.parameters = { value }
                    try renderer.exportPNG(to: directory.appendingPathComponent(name+".png"),width: width,height: height)
                }
                if let assetIndex = CommandLine.arguments.firstIndex(of: "--asset"),CommandLine.arguments.count > assetIndex+1 {
                    let asset = try ReminderAsset.read(url: URL(fileURLWithPath: CommandLine.arguments[assetIndex+1])).asset
                    for (name,time,reduced) in [("asset-first",0.0,false),("asset-later",0.2,false),("asset-reduced",0.2,true)] {
                        var value = baseline; value.asset = asset; value.time = time; value.effect.travel = 0
                        value.effect.gravity = 8; value.reducedMotion = reduced
                        renderer.parameters = { value }
                        try renderer.exportPNG(to: directory.appendingPathComponent(name+".png"))
                    }
                }
                print("Rendered \(cases.count+1+variants.count) shader checks to \(directory.path)")
            } catch { print("Render check failed: \(error)"); exit(1) }
            return
        }
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { app.run() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = AppModel()
    private var window: NSWindow!
    private var status: NSStatusItem!
    private let sessionItem = NSMenuItem()
    private let breakItem = NSMenuItem()
    private let stopItem = NSMenuItem()
    private var openItem: NSMenuItem!
    private var quitItem: NSMenuItem!
    private var focusItems: [NSMenuItem] = []
    private var restItems: [NSMenuItem] = []
    private var statusLength: CGFloat = 76
    private var statusPaused = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(self,andSelector: #selector(handleURL(_:reply:)),forEventClass: AEEventClass(kInternetEventClass),andEventID: AEEventID(kAEGetURL))
        setupMainMenu()
        window = NSWindow(contentRect: NSRect(x: 0,y: 0,width: 960,height: 680),styleMask: [.titled,.closable,.miniaturizable,.resizable,.fullSizeContentView],backing: .buffered,defer: false)
        window.title = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Focused Break"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.minSize = NSSize(width: 820,height: 620)
        window.backgroundColor = NSColor(Theme.background)
        window.appearance = NSAppearance(named: .aqua)
        window.contentView = NSHostingView(rootView: MainView(model: model).padding(.top,24).background(Theme.background).preferredColorScheme(.light))
        window.center()
        let statusName = "EventHorizon.Session"
        // Seed only the first placement near the right edge; preserve later user moves.
        let positionKey = "NSStatusItem Preferred Position \(statusName)"
        if UserDefaults.standard.object(forKey: positionKey) == nil { UserDefaults.standard.set(0,forKey: positionKey) }
        status = NSStatusBar.system.statusItem(withLength: 76)
        status.autosaveName = statusName
        status.isVisible = true
        status.button?.image = NSImage(systemSymbolName: "pause.fill",accessibilityDescription: "Focused Break")
        status.button?.imagePosition = .imageLeading
        status.button?.font = .monospacedDigitSystemFont(ofSize: 12,weight: .medium)
        let menu = NSMenu()
        openItem = item("Open Focused Break",#selector(showWindow),""); menu.addItem(openItem)
        menu.addItem(.separator())
        sessionItem.target = self; sessionItem.action = #selector(toggleSession); menu.addItem(sessionItem)
        breakItem.title = "Take break now"; breakItem.target = self; breakItem.action = #selector(takeBreak); menu.addItem(breakItem)
        stopItem.title = "End session / hide effect"; stopItem.target = self; stopItem.action = #selector(stopSession); menu.addItem(stopItem)
        menu.addItem(.separator())
        for (title,values,isFocus) in [("Focus duration",TimerOptions.focus,true),("Break duration",TimerOptions.rest,false)] {
            let parent = NSMenuItem(title: title,action: nil,keyEquivalent: "")
            let submenu = NSMenu(title: title); submenu.autoenablesItems = false
            for minutes in values {
                let option = item(TimerOptions.label(minutes),isFocus ? #selector(setFocus(_:)) : #selector(setBreak(_:)),"")
                option.tag = minutes; submenu.addItem(option)
                if isFocus { focusItems.append(option) } else { restItems.append(option) }
            }
            parent.submenu = submenu; menu.addItem(parent)
        }
        menu.addItem(.separator())
        quitItem = item("Quit Focused Break",#selector(quit),"q"); menu.addItem(quitItem)
        menu.autoenablesItems = false; status.menu = menu
        model.onUpdate = { [weak self] in self?.updateMenu() }
        model.onBreakCompleted = { [weak self] in self?.showWindow() }
        model.onBreakStarted = { [weak self] in
            self?.window.orderOut(nil)
            NSApp.setActivationPolicy(.accessory)
        }
        updateMenu(); showWindow()
        if CommandLine.arguments.contains("--diagnostics") {
            if CommandLine.arguments.contains("--desktop-diagnostics") {
                DispatchQueue.main.asyncAfter(deadline: .now()+2) { [weak self] in self?.model.testOnDesktop() }
            }
            DispatchQueue.main.asyncAfter(deadline: .now()+12) { [weak self] in
                let report = self?.model.performanceReports() ?? [:]
                if let data = try? JSONSerialization.data(withJSONObject: report,options: [.sortedKeys]), let text = String(data: data,encoding: .utf8) { print("RENDER_METRICS "+text) }
                NSApp.terminate(nil)
            }
        }
    }
    private func item(_ title: String,_ selector: Selector,_ key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title,action: selector,keyEquivalent: key); item.target = self; return item
    }
    private func setupMainMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem(); let appMenu = NSMenu(); appItem.submenu = appMenu
        appMenu.addItem(item("About Focused Break",#selector(showWindow),""))
        appMenu.addItem(.separator())
        appMenu.addItem(item("Hide Focused Break",#selector(NSApplication.hide(_:)),"h")); appMenu.items.last?.target = NSApp
        appMenu.addItem(item("Quit Focused Break",#selector(quit),"q")); menu.addItem(appItem)
        let session = NSMenuItem(); session.title = "Session"; let sessionMenu = NSMenu(title: "Session"); session.submenu = sessionMenu
        let controls = item("Show menu-bar controls",#selector(showStatusMenu),"m")
        controls.keyEquivalentModifierMask = [.command,.shift]; sessionMenu.addItem(controls)
        sessionMenu.addItem(.separator())
        sessionMenu.addItem(item("Start / Pause / Resume",#selector(toggleSession),"p"))
        sessionMenu.addItem(item("Take break now",#selector(takeBreak),"b"))
        sessionMenu.addItem(item("End session",#selector(stopSession),"."))
        menu.addItem(session)
        NSApp.mainMenu = menu
    }
    private func updateMenu() {
        let length: CGFloat = model.session.isActive || model.isTesting ? 76 : NSStatusItem.squareLength
        if statusLength != length { statusLength = length; status?.length = length }
        let title = model.isTesting ? " \(model.testRemaining)s" : model.session.isActive ? " \(model.clockText)" : ""
        if status?.button?.title != title { status?.button?.title = title }
        if statusPaused != model.session.isPaused {
            statusPaused = model.session.isPaused
            status?.button?.image = NSImage(systemSymbolName: statusPaused ? "pause.circle" : "pause.fill",accessibilityDescription: "Focused Break")
        }
        status?.button?.setAccessibilityLabel("Focused Break · \(model.phaseTitle) · \(model.clockText)")
        status?.button?.toolTip = "Focused Break · \(model.phaseTitle)"
        sessionItem.title = model.session.isActive ? (model.session.isPaused ? "Resume session" : "Pause session") : model.session.phase == .complete ? "Start next focus" : "Start session"
        sessionItem.isEnabled = (!model.breakLocked || model.session.isPaused) && !model.isTesting
        breakItem.isEnabled = model.session.phase == .focus
        stopItem.title = model.breakLocked ? "Break protected · \(model.breakLockRemaining)s" : model.session.phase == .rest ? "End break" : "Stop session"
        stopItem.isEnabled = !model.breakLocked && (model.session.isActive || model.isTesting || model.session.phase == .complete)
        openItem.isEnabled = !model.session.showsDesktopEffect
        quitItem.isEnabled = true
        for option in focusItems {
            option.state = option.tag == model.focusMinutes ? .on : .off
            option.isEnabled = !model.session.isActive && !model.isTesting
        }
        for option in restItems {
            option.state = option.tag == model.breakMinutes ? .on : .off
            option.isEnabled = !model.session.isActive && !model.isTesting
        }
    }
    @objc func showWindow() {
        guard !model.session.showsDesktopEffect else { return }
        NSApp.setActivationPolicy(.regular)
        // Activation-policy changes settle on the next run-loop turn.
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.model.session.showsDesktopEffect, let window = self.window else { return }
            let behavior = window.collectionBehavior
            window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            if window.isMiniaturized { window.deminiaturize(nil) }
            NSApp.unhide(nil)
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            window.collectionBehavior = behavior
        }
    }
    @objc func showStatusMenu() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let button = self.status.button, let menu = self.status.menu else { return }
            menu.popUp(positioning: nil,at: NSPoint(x: 0,y: button.bounds.minY),in: button)
        }
    }
    func windowWillClose(_ notification: Notification) { NSApp.setActivationPolicy(.accessory) }
    @objc func setFocus(_ sender: NSMenuItem) {
        guard !model.session.isActive && !model.isTesting else { return }
        model.focusMinutes = sender.tag; updateMenu()
    }
    @objc func setBreak(_ sender: NSMenuItem) {
        guard !model.session.isActive && !model.isTesting else { return }
        model.breakMinutes = sender.tag; updateMenu()
    }
    @objc func toggleSession() { model.session.isActive ? model.togglePause() : model.start() }
    @objc func takeBreak() { model.takeBreak() }
    @objc func stopSession() { model.stop() }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication,hasVisibleWindows flag: Bool) -> Bool { showWindow(); return true }
    func applicationWillTerminate(_ notification: Notification) { model.terminate() }
    @objc func handleURL(_ event: NSAppleEventDescriptor,reply: NSAppleEventDescriptor) {
        guard let value = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: value),
              url.scheme?.lowercased() == (Bundle.main.bundleIdentifier?.hasSuffix(".preview") == true ? "eventhorizonpreview" : "eventhorizon") else { return }
        switch url.host?.lowercased() {
        case "start": model.start()
        case "demo": model.testOnDesktop()
        case "pause": if model.session.isActive && !model.session.isPaused { model.togglePause() }
        case "resume": if model.session.isPaused { model.togglePause() }
        case "break": model.takeBreak()
        case "stop": model.stop()
        case "show": showWindow()
        default: break
        }
    }
}
