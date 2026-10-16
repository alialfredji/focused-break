import SwiftUI
import HorizonCore

enum Theme {
    static let background = Color(red: 1,green: 0.965,blue: 0.89)
    static let panel = Color(red: 1,green: 0.99,blue: 0.96)
    static let ink = Color(red: 0.24,green: 0.105,blue: 0.045)
    static let muted = Color(red: 0.43,green: 0.31,blue: 0.23)
    static let accent = Color(red: 0.65,green: 0.27,blue: 0.025)
    static let brand = Color(red: 1,green: 0.67,blue: 0)
    static let line = ink.opacity(0.16)
}

struct MainView: View {
    @ObservedObject var model: AppModel
    @State private var previewExpanded = false
    @State private var adjustmentsExpanded = false
    @State private var appearanceExpanded = false
    var body: some View {
        VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable().scaledToFit().frame(width: 24,height: 24).accessibilityHidden(true)
                    Text("Focused Break").font(.system(size: 13,weight: .semibold))
                    Spacer()
                    if Bundle.main.bundleIdentifier?.hasSuffix(".preview") == true {
                        Text("Preview build").font(.system(size: 12)).foregroundStyle(Theme.muted)
                    }
                }.padding(.horizontal,20).padding(.vertical,12)
                Rectangle().fill(Theme.line.opacity(0.35)).frame(height: 1)
                HStack(alignment: .top,spacing: 24) {
                    VStack(spacing: 24) {
                        Spacer(minLength: 24)
                        sessionControls
                        Spacer(minLength: 24)
                    }.frame(maxWidth: .infinity,maxHeight: .infinity)
                    ScrollView(showsIndicators: false) {
                VStack(alignment: .leading,spacing: 16) {
                    VStack(alignment: .leading,spacing: 5) {
                        Text("Break appearance").font(.system(size: 16,weight: .semibold))
                        Text("What appears when it’s time to rest.")
                            .font(.system(size: 12)).foregroundStyle(Theme.muted)
                    }.padding(.bottom,4)
                    appearance
                    effects
                    Rectangle().fill(Theme.line.opacity(0.4)).frame(height: 1)
                    drawerHeader("Preview",expanded: $previewExpanded)
                    if previewExpanded { preview }
                }.padding(12).floatingPanel().padding(4)
                    }.frame(width: 316)
                }.padding(20)
                if let message = model.error ?? model.notice {
                    Text(message).font(.system(size: 12)).foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity,alignment: .leading)
                }
        }.font(.system(size: 13,weight: .medium)).buttonStyle(ToolButtonStyle())
            .foregroundStyle(Theme.ink).background(Theme.background).tint(Theme.accent).accentColor(Theme.accent)
            .frame(minWidth: 820,minHeight: 580).onExitCommand { model.stop() }
    }
    private var sessionControls: some View {
        VStack(spacing: 18) {
            Text(model.session.phase == .complete ? "Break over · next focus" : model.phaseTitle).font(.system(size: 13,weight: .medium)).foregroundStyle(Theme.muted)
            Text(model.clockText).font(.system(size: 76,weight: .regular)).monospacedDigit().tracking(-3)
                .accessibilityLabel(model.session.isActive ? "\(model.clockText) remaining" : "Next focus: \(model.clockText)")
            if model.session.isActive {
                ProgressView(value: model.session.progress).tint(Theme.accent)
                    .accessibilityLabel("Session progress").frame(maxWidth: 320)
            }
            HStack(alignment: .top,spacing: 4) {
                duration("Focus time",icon: "timer",selection: $model.focusMinutes,values: TimerOptions.focus)
                duration("Break time",icon: "cup.and.saucer",selection: $model.breakMinutes,values: TimerOptions.rest)
                NumberChoice(title: "End break after",icon: "lock.open",selection: $model.minimumBreakSeconds,values: Array(stride(from: 5,through: 300,by: 5)),unit: "sec")
                    .help("Pause and End are unavailable until this time passes. Quit always works.")
            }.padding(6).floatingPanel().disabled(model.session.isActive || model.isTesting)
            Button(action: { model.session.isActive ? model.togglePause() : model.start() }) {
                Label(model.session.isActive ? (model.session.isPaused ? "Resume" : "Pause") : model.session.phase == .complete ? "Start next focus" : "Start focus",
                      systemImage: model.session.isActive && !model.session.isPaused ? "pause.fill" : "play.fill")
                    .frame(maxWidth: .infinity).frame(height: 42)
            }.buttonStyle(PrimaryStyle()).frame(maxWidth: 220).keyboardShortcut(.return,modifiers: [])
                .disabled(model.isTesting || (model.breakLocked && !model.session.isPaused))
            if model.session.isActive {
                HStack(spacing: 28) {
                    if model.session.phase == .focus { Button("Take break now") { model.takeBreak() } }
                    Button(model.session.phase == .rest ? "End break" : "End session") { model.stop() }.disabled(model.breakLocked)
                }.buttonStyle(.borderless).font(.system(size: 12)).tint(Theme.muted)
                if model.breakLocked {
                    Text("Break protected · \(model.breakLockRemaining)s").font(.system(size: 12)).foregroundStyle(Theme.accent)
                }
            }
        }.padding(.vertical,12).frame(maxWidth: .infinity)
    }
    private var appearance: some View {
        VStack(alignment: .leading,spacing: 12) {
            VStack(alignment: .leading,spacing: 10) {
                Text("Visual").font(.system(size: 12,weight: .semibold)).foregroundStyle(Theme.muted)
                Button { appearanceExpanded.toggle() } label: {
                    HStack(spacing: 10) {
                        appearanceIcon(model.appearance)
                        Text(appearanceName(model.appearance))
                        Spacer()
                        Image(systemName: "chevron.down").font(.system(size: 10,weight: .semibold))
                    }.frame(maxWidth: .infinity).frame(height: 28)
                }.background(Theme.ink.opacity(0.035),in: RoundedRectangle(cornerRadius: 8)).popover(isPresented: $appearanceExpanded,arrowEdge: .bottom) {
                    VStack(spacing: 4) {
                        ForEach([BreakAppearance.blackHole,.haveABreak,.custom],id: \.self) { choice in
                            Button {
                                appearanceExpanded = false
                                model.selectAppearance(choice)
                            } label: {
                                HStack(spacing: 12) {
                                    appearanceIcon(choice)
                                    Text(appearanceName(choice))
                                    Spacer()
                                    if model.appearance == choice { Image(systemName: "checkmark").font(.system(size: 11,weight: .semibold)) }
                                }.frame(width: 220,height: 28)
                            }.buttonStyle(ToolButtonStyle(selected: model.appearance == choice))
                        }
                    }.padding(8).background(Theme.panel).foregroundStyle(Theme.ink)
                        .font(.system(size: 13,weight: .medium))
                }.disabled(model.importingAsset).accessibilityLabel("Break appearance: \(appearanceName(model.appearance))")
            }
            if model.appearance == .custom, let asset = model.reminderAsset {
                HStack(spacing: 8) {
                    Text(asset.name).lineLimit(1).truncationMode(.middle).foregroundStyle(Theme.muted)
                    Spacer()
                    Button("Replace") { model.chooseAsset() }
                        .help("Replace image").accessibilityLabel("Replace image")
                    Button("Remove") { model.removeAsset() }
                        .help("Remove image").accessibilityLabel("Remove image")
                }.font(.system(size: 12)).disabled(model.importingAsset)
            }
            if model.importingAsset { ProgressView("Loading image…").controlSize(.small) }
            if let error = model.assetError { Text(error).font(.system(size: 12)).foregroundStyle(Theme.accent) }
        }
    }
    private func appearanceName(_ choice: BreakAppearance) -> String {
        switch choice {
        case .blackHole: return "Black hole"
        case .haveABreak: return "Have a break"
        case .custom: return "My image"
        }
    }
    @ViewBuilder private func appearanceIcon(_ choice: BreakAppearance) -> some View {
        if choice == .blackHole {
            Image(systemName: "circle.circle.fill").font(.system(size: 22)).frame(width: 28,height: 28)
        } else if choice == .custom && model.appearance == .custom, let asset = model.reminderAsset {
            Image(nsImage: NSImage(cgImage: asset.frames[0],size: .zero)).resizable().scaledToFit().frame(width: 28,height: 28)
        } else if choice == .haveABreak, let url = Bundle.main.url(forResource: "HaveABreak",withExtension: "gif") ?? Bundle.module.url(forResource: "HaveABreak",withExtension: "gif"),
                  let image = NSImage(contentsOf: url) {
            Image(nsImage: image).resizable().scaledToFit().frame(width: 28,height: 28)
        } else {
            Image(systemName: "photo.badge.plus").font(.system(size: 20)).frame(width: 28,height: 28)
        }
    }
    private var effects: some View {
        VStack(alignment: .leading,spacing: 16) {
            VStack(alignment: .leading,spacing: 8) {
                Text("Size").font(.system(size: 12,weight: .semibold)).foregroundStyle(Theme.muted)
                HStack(spacing: 2) {
                    sizeButton("Small",0.12)
                    sizeButton("Medium",0.55)
                    sizeButton("Large",1.4)
                }.padding(3).background(Theme.ink.opacity(0.035),in: RoundedRectangle(cornerRadius: 8))
            }
            Rectangle().fill(Theme.line.opacity(0.4)).frame(height: 1)
            VStack(alignment: .leading,spacing: 8) {
            Text("Motion & distortion").font(.system(size: 12,weight: .semibold)).foregroundStyle(Theme.muted)
            HStack(spacing: 0) {
                Toggle("Distort desktop",isOn: Binding(get: { model.desktopLens },set: { model.setDesktopLens($0) }))
                    .help("Distort the desktop during breaks.")
                Toggle("Reduce motion",isOn: $model.reduceMotion)
                    .help("Stops movement and rim animation. GIFs stay on their first frame.")
                Spacer(minLength: 0)
            }.toggleStyle(ToolToggleStyle()).font(.system(size: 12,weight: .medium))
            }
            drawerHeader("Fine-tune",expanded: $adjustmentsExpanded)
            if adjustmentsExpanded {
                VStack(spacing: 16) {
                    HStack {
                        Text("Preset").font(.system(size: 12)).foregroundStyle(Theme.muted)
                        Spacer()
                        PresetChoice(model: model)
                    }
                    VStack(spacing: 16) {
                        effectSlider("Size",value: $model.effect.size,range: 0.12...1.4,format: "%.2f×")
                        effectSlider("Gravity",value: $model.effect.gravity,range: 0...10,format: "%.1f×")
                    }
                    VStack(spacing: 16) {
                        effectSlider("Movement range",value: $model.effect.travel,range: 0...1,format: "%.0f%%",scale: 100)
                        effectSlider("Movement speed",value: $model.effect.travelSpeed,range: 0...10,format: "%.1f×")
                    }
                    effectSlider("Field reach",value: $model.lensReach,range: 0.5...2,format: "%.1f×")
                    if !model.customAppearance {
                        VStack(spacing: 16) {
                            effectSlider("Rim brightness",value: $model.rimBrightness,range: 0...2,format: "%.0f%%",scale: 100)
                            effectSlider("Rim width",value: $model.rimWidth,range: 0.015...0.15,format: "%.1f%%",scale: 100)
                        }
                    }
                }.padding(.horizontal,8).padding(.top,4)
            }
            if model.desktopLens && (model.lensStatus == "Access unavailable" || model.lensStatus == "Capture stopped") {
                HStack {
                    Button("Open Privacy Settings") { model.openPrivacySettings() }
                    Button("Recheck access") { model.setDesktopLens(true) }
                }.buttonStyle(.link).font(.system(size: 12))
            }
        }
    }
    private var preview: some View {
        VStack(spacing: 14) {
            HStack(spacing: 4) {
                previewChoice("Live desktop",icon: "desktopcomputer",background: .desktop)
                previewChoice("Grid",icon: "square.grid.3x3",background: .grid)
                previewChoice("Space",icon: "sparkles",background: .space)
                Spacer(minLength: 0)
            }.padding(4).background(Theme.background,in: RoundedRectangle(cornerRadius: 10))
            if model.previewBackground == .desktop && !model.desktopLens {
                VStack(spacing: 12) {
                    Text("Enable desktop access to preview your screen.").foregroundStyle(Theme.muted)
                    Button("Enable live desktop") { model.setDesktopLens(true) }
                }.font(.system(size: 12)).frame(maxWidth: .infinity).frame(height: 180)
            } else {
                ZStack {
                    HolePreview(model: model).frame(height: 240).accessibilityHidden(true)
                    if model.previewBackground == .desktop && model.previewCaptureStatus != "Live" {
                        Theme.panel
                        Text(model.previewCaptureStatus == "Connecting…" ? "Connecting to desktop…" : "Desktop preview unavailable. Check screen access.")
                            .font(.system(size: 12)).foregroundStyle(Theme.muted)
                    }
                }.frame(height: 240).clipShape(RoundedRectangle(cornerRadius: 8))
            }
            HStack(spacing: 16) {
                Button { model.togglePreview() } label: { Image(systemName: model.previewPlaying ? "pause.fill" : "play.fill") }
                    .accessibilityLabel(model.previewPlaying ? "Pause preview" : "Play preview")
                Button { model.replayPreview() } label: { Image(systemName: "arrow.counterclockwise") }.accessibilityLabel("Restart preview")
                Spacer()
                Button(model.isTesting ? "Stop test · \(model.testRemaining)s" : "Test on desktop · 10s") {
                    model.isTesting ? model.endDesktopTest() : model.testOnDesktop()
                }.disabled(model.session.isActive)
            }.buttonStyle(ToolButtonStyle()).font(.system(size: 12)).tint(Theme.accent)
        }
    }
    private func previewChoice(_ title: String,icon: String,background: PreviewBackground) -> some View {
        Button { model.previewBackground = background } label: { Label(title,systemImage: icon) }
            .buttonStyle(ToolButtonStyle(selected: model.previewBackground == background))
            .accessibilityAddTraits(model.previewBackground == background ? .isSelected : [])
    }
    private func drawerHeader(_ title: String,expanded: Binding<Bool>) -> some View {
        Button { expanded.wrappedValue.toggle() } label: {
            HStack(spacing: 10) {
                Text(title)
                Spacer()
                Image(systemName: expanded.wrappedValue ? "chevron.up" : "chevron.down").font(.system(size: 10,weight: .semibold))
            }.frame(maxWidth: .infinity).frame(height: 22)
        }.buttonStyle(ToolButtonStyle()).accessibilityValue(expanded.wrappedValue ? "Expanded" : "Collapsed")
    }
    private func sizeButton(_ title: String,_ size: Double) -> some View {
        Button { model.effect.size = size } label: { Text(title).frame(maxWidth: .infinity) }
            .buttonStyle(ToolButtonStyle(selected: abs(model.effect.size-size) < 0.001))
            .accessibilityAddTraits(abs(model.effect.size-size) < 0.001 ? .isSelected : [])
    }
    private func duration(_ title: String,icon: String,selection: Binding<Int>,values: [Int]) -> some View {
        NumberChoice(title: title,icon: icon,selection: selection,values: values,unit: "min")
    }
    private func effectSlider(_ title: String,value: Binding<Double>,range: ClosedRange<Double>,format: String,scale: Double = 1) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(title); Spacer()
                Text(String(format: format,value.wrappedValue*scale)).monospacedDigit().foregroundStyle(Theme.muted)
            }.font(.system(size: 12))
            Slider(value: value,in: range).controlSize(.small).tint(Theme.accent).accessibilityLabel(title)
        }
    }
}

private extension View {
    func floatingPanel() -> some View {
        background(Theme.panel,in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.ink.opacity(0.08)))
            .shadow(color: Theme.ink.opacity(0.12),radius: 2,x: 0,y: 2)
            .shadow(color: Theme.ink.opacity(0.04),radius: 8,x: 0,y: 3)
    }
}

private struct NumberChoice: View {
    let title: String
    let icon: String
    @Binding var selection: Int
    let values: [Int]
    let unit: String
    @State private var expanded = false
    var body: some View {
        Button { expanded.toggle() } label: {
            VStack(alignment: .leading,spacing: 9) {
                Text(title).font(.system(size: 11)).foregroundStyle(Theme.muted).lineLimit(1)
                HStack(spacing: 6) {
                    Image(systemName: icon).font(.system(size: 14))
                    Text("\(selection) \(unit)").monospacedDigit()
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down").font(.system(size: 8,weight: .semibold))
                }
            }.frame(maxWidth: .infinity,alignment: .leading).padding(.vertical,4)
        }.buttonStyle(ToolButtonStyle()).accessibilityLabel("\(title): \(selection) \(unit)")
            .popover(isPresented: $expanded,arrowEdge: .bottom) {
                VStack(alignment: .leading,spacing: 12) {
                    Text(title).font(.system(size: 12,weight: .semibold)).padding(.horizontal,8)
                    ScrollView(showsIndicators: false) {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(),spacing: 4),count: 4),spacing: 4) {
                            ForEach(values,id: \.self) { value in
                                Button { selection = value; expanded = false } label: {
                                    Text("\(value)").monospacedDigit().frame(maxWidth: .infinity).frame(height: 24)
                                }.buttonStyle(ToolButtonStyle(selected: selection == value))
                                    .accessibilityLabel("\(value) \(unit)")
                            }
                        }
                    }.frame(maxHeight: 280)
                    Text(unit == "min" ? "Minutes" : "Seconds").font(.system(size: 11)).foregroundStyle(Theme.muted).padding(.horizontal,8)
                }.padding(12).frame(width: 260).background(Theme.panel).foregroundStyle(Theme.ink)
            }
    }
}

private struct PresetChoice: View {
    @ObservedObject var model: AppModel
    @State private var expanded = false
    var body: some View {
        Button { expanded.toggle() } label: {
            HStack(spacing: 12) {
                Text(model.effect.preset)
                Image(systemName: "chevron.down").font(.system(size: 9,weight: .semibold))
            }.frame(height: 20)
        }.buttonStyle(ToolButtonStyle()).accessibilityLabel("Effect preset: \(model.effect.preset)")
            .popover(isPresented: $expanded) {
                VStack(spacing: 4) {
                    ForEach(["Default","Gentle","Strong","Extreme"],id: \.self) { name in
                        Button {
                            switch name {
                            case "Gentle": model.effect = .gentle
                            case "Strong": model.effect = .strong
                            case "Extreme": model.effect = .extreme
                            default: model.resetEffectDefaults()
                            }
                            expanded = false
                        } label: {
                            HStack { Text(name); Spacer(); if model.effect.preset == name { Image(systemName: "checkmark") } }.frame(width: 140,height: 24)
                        }.buttonStyle(ToolButtonStyle(selected: model.effect.preset == name))
                    }
                }.padding(6).background(Theme.panel)
            }
    }
}

struct ToolButtonStyle: ButtonStyle {
    var selected = false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        ToolButtonBody(content: configuration.label,selected: selected,pressed: configuration.isPressed,enabled: enabled)
    }
}
private struct ToolButtonBody<Content: View>: View {
    let content: Content
    let selected: Bool
    let pressed: Bool
    let enabled: Bool
    @State private var hovered = false
    var body: some View {
        content.font(.system(size: 12,weight: .medium))
            .foregroundStyle(Theme.ink.opacity(enabled ? 1 : 0.4))
            .padding(.horizontal,10).padding(.vertical,8)
            .background(selected ? Theme.brand.opacity(0.22) : Theme.ink.opacity(pressed ? 0.1 : hovered && enabled ? 0.05 : 0),in: RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8)).onHover { hovered = $0 }
    }
}
struct ToolToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(spacing: 8) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 16,weight: .regular)).foregroundStyle(configuration.isOn ? Theme.accent : Theme.muted)
                configuration.label
            }
        }.buttonStyle(ToolButtonStyle(selected: configuration.isOn))
            .accessibilityValue(configuration.isOn ? "On" : "Off")
    }
}

struct PrimaryStyle: ButtonStyle {
    @Environment(\.isEnabled) var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 14,weight: .semibold)).foregroundStyle(Theme.ink.opacity(enabled ? 1 : 0.6))
            .background(Theme.brand.opacity(enabled ? (configuration.isPressed ? 0.72 : 1) : 0.4),in: RoundedRectangle(cornerRadius: 10))
            .contentShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct BreakCard: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading,spacing: 12) {
            HStack {
                Text(model.isTesting ? "Desktop preview" : model.session.phase == .complete ? "Break over" : "Break").font(.system(size: 18,weight: .medium))
                Spacer()
                Text(model.isTesting ? "\(model.testRemaining)s" : model.clockText)
                    .font(.system(size: 18,design: .monospaced)).foregroundStyle(Theme.accent)
            }
            HStack {
                if model.session.phase == .complete && !model.isTesting {
                    Button("Later") { model.dismissCompletion() }.buttonStyle(.borderless).tint(Theme.muted)
                    Spacer()
                    Button("Start next focus") { model.start() }.buttonStyle(.borderedProminent).tint(Theme.accent)
                } else {
                    Text(model.isTesting ? "Closes automatically" : "Focus starts when you choose")
                        .font(.system(size: 11)).foregroundStyle(Theme.muted)
                    Spacer()
                    Button(model.isTesting ? "Stop preview" : "End break") { model.stop() }
                        .buttonStyle(.bordered).controlSize(.small).disabled(model.breakLocked)
                }
            }
        }.padding(20).background(Theme.panel,in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line))
            .foregroundStyle(Theme.ink).tint(Theme.accent).onExitCommand { model.stop() }
    }
}
